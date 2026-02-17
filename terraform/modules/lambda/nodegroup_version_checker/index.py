import json
import os
import time
from typing import Dict, List
import boto3
from botocore.exceptions import ClientError

eks_client = boto3.client('eks')
sns_client = boto3.client('sns')


def retry_with_backoff(func, *args, max_retries=3, **kwargs):
    for attempt in range(max_retries):
        try:
            return func(*args, **kwargs)
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            if error_code in ['Throttling', 'TooManyRequestsException', 'RequestLimitExceeded']:
                if attempt < max_retries - 1:
                    time.sleep(2 ** attempt)
                else:
                    raise
            else:
                raise


def get_cluster_nodegroups(cluster_name: str) -> List[Dict]:
    try:
        response = retry_with_backoff(eks_client.list_nodegroups, clusterName=cluster_name)
        nodegroup_names = response.get('nodegroups', [])
        if not nodegroup_names:
            return []
        nodegroups = []
        for ng_name in nodegroup_names:
            try:
                ng_response = retry_with_backoff(eks_client.describe_nodegroup, clusterName=cluster_name, nodegroupName=ng_name)
                ng_details = ng_response.get('nodegroup', {})
                nodegroups.append({
                    'nodegroup_name': ng_details.get('nodegroupName'),
                    'kubernetes_version': ng_details.get('version'),
                    'release_version': ng_details.get('releaseVersion'),
                    'status': ng_details.get('status'),
                    'launch_template': ng_details.get('launchTemplate')
                })
            except ClientError as e:
                print(f"Error describing node group {ng_name}: {e}")
                continue
        return nodegroups
    except ClientError as e:
        print(f"Error listing node groups for cluster {cluster_name}: {e}")
        return []


def check_nodegroup_update_available(current_k8s_version: str, cluster_k8s_version: str) -> bool:
    """True if node group version differs from cluster (update needed)."""
    return current_k8s_version != cluster_k8s_version


def update_nodegroup_version(cluster_name: str, nodegroup_name: str, target_k8s_version: str) -> Dict:
    try:
        response = retry_with_backoff(
            eks_client.update_nodegroup_version,
            clusterName=cluster_name,
            nodegroupName=nodegroup_name,
            version=target_k8s_version,
            force=False
        )
        update_id = response.get('update', {}).get('id')
        return {'success': True, 'update_id': update_id, 'error': None}
    except ClientError as e:
        return {'success': False, 'update_id': None, 'error': str(e)}


def send_nodegroup_summary(cluster_name: str, nodegroup_results: List[Dict], sns_topic_arn: str) -> None:
    updating = [r for r in nodegroup_results if r['status'] == 'updating']
    failed = [r for r in nodegroup_results if r['status'] == 'failed']
    up_to_date = [r for r in nodegroup_results if r['status'] == 'up_to_date']
    update_available = [r for r in nodegroup_results if r['status'] == 'update_available']
    skipped = [r for r in nodegroup_results if r['status'] == 'skipped']
    if failed:
        overall_status = f"{len(failed)} Failed"
    elif updating:
        overall_status = f"{len(updating)} Updating"
    elif update_available:
        overall_status = f"{len(update_available)} Update Available"
    else:
        overall_status = "All Up-to-Date"
    subject = f"EKS Node Group Summary - {cluster_name} - {overall_status}"
    message_lines = [
        f"Cluster: {cluster_name}",
        f"Total Node Groups: {len(nodegroup_results)}",
        f"Up-to-Date: {len(up_to_date)}",
        f"Update Available: {len(update_available)}",
        f"Updating: {len(updating)}",
        f"Failed: {len(failed)}",
        f"Skipped: {len(skipped)}",
        "", "=" * 60, ""
    ]
    if updating:
        message_lines.append("UPDATING NODE GROUPS:")
        message_lines.append("-" * 60)
        for result in updating:
            message_lines.append(f"  Node Group: {result['nodegroup_name']}")
            message_lines.append(f"  Kubernetes Version: {result['current_version']} -> {result['target_version']}")
            message_lines.append(f"  AMI Release: {result['current_ami']} -> Latest")
            message_lines.append(f"  Update ID: {result['update_id']}")
            message_lines.append("")
    if failed:
        message_lines.append("FAILED NODE GROUPS:")
        message_lines.append("-" * 60)
        for result in failed:
            message_lines.append(f"  Node Group: {result['nodegroup_name']}")
            message_lines.append(f"  Current Version: {result['current_version']}")
            message_lines.append(f"  Target Version: {result['target_version']}")
            message_lines.append(f"  Error: {result['error']}")
            err = result.get('error') or ''
            if 'PodEvictionFailure' in err or 'PDB' in err:
                message_lines.append("")
                message_lines.append("  ACTION REQUIRED: To force update, run:")
                message_lines.append(f"  aws eks update-nodegroup-version \\")
                message_lines.append(f"    --cluster-name {cluster_name} \\")
                message_lines.append(f"    --nodegroup-name {result['nodegroup_name']} \\")
                message_lines.append(f"    --force")
            message_lines.append("")
    if update_available:
        message_lines.append("UPDATE AVAILABLE (auto-upgrade disabled):")
        message_lines.append("-" * 60)
        for result in update_available:
            message_lines.append(f"  {result['nodegroup_name']}: {result['current_version']} -> {result['target_version']}")
        message_lines.append("")
    if up_to_date:
        message_lines.append("UP-TO-DATE NODE GROUPS:")
        message_lines.append("-" * 60)
        for result in up_to_date:
            message_lines.append(f"  {result['nodegroup_name']} ({result['current_version']}, AMI: {result['current_ami']})")
        message_lines.append("")
    if skipped:
        message_lines.append("SKIPPED (not ACTIVE):")
        message_lines.append("-" * 60)
        for result in skipped:
            message_lines.append(f"  {result['nodegroup_name']}: {result.get('error', result['status'])}")
        message_lines.append("")
    try:
        sns_client.publish(TopicArn=sns_topic_arn, Subject=subject, Message="\n".join(message_lines))
    except ClientError as e:
        print(f"Error sending SNS notification: {e}")


def process_cluster_nodegroups(cluster_name: str, cluster_k8s_version: str, sns_topic_arn: str) -> List[Dict]:
    ENABLE_AUTO_UPGRADE = os.environ.get('ENABLE_AUTO_UPGRADE', 'true').lower() == 'true'
    nodegroups = get_cluster_nodegroups(cluster_name)
    if not nodegroups:
        return []
    if not cluster_k8s_version:
        print(f"Cluster {cluster_name} has no version; skipping node groups")
        return []
    results = []
    for ng in nodegroups:
        ng_name = ng['nodegroup_name']
        current_version = ng['kubernetes_version']
        current_ami = ng['release_version']
        ng_status = ng.get('status', '')
        result = {
            'nodegroup_name': ng_name, 'status': 'up_to_date', 'current_version': current_version,
            'target_version': None, 'current_ami': current_ami, 'update_id': None, 'error': None
        }
        try:
            if ng_status and ng_status != 'ACTIVE':
                result['status'] = 'skipped'
                result['error'] = f"Node group status is {ng_status}, not ACTIVE"
                results.append(result)
                continue
            needs_update = check_nodegroup_update_available(current_version, cluster_k8s_version)
            if not needs_update:
                results.append(result)
                continue
            result['target_version'] = cluster_k8s_version
            if ENABLE_AUTO_UPGRADE:
                update_result = update_nodegroup_version(cluster_name, ng_name, cluster_k8s_version)
                if update_result['success']:
                    result['status'] = 'updating'
                    result['update_id'] = update_result['update_id']
                else:
                    result['status'] = 'failed'
                    result['error'] = update_result['error']
            else:
                result['status'] = 'update_available'
            results.append(result)
        except Exception as e:
            result['status'] = 'failed'
            result['target_version'] = cluster_k8s_version
            result['error'] = str(e)
            results.append(result)
    send_nodegroup_summary(cluster_name, results, sns_topic_arn)
    return results


def cluster_matches_target_environments(cluster_name: str, cluster_tags: Dict[str, str], target_envs: List[str]) -> bool:
    if not target_envs:
        return True
    name_lower = cluster_name.lower()
    env_tag = (cluster_tags.get('Environment') or cluster_tags.get('environment') or cluster_tags.get('Env') or '').lower()
    for t in target_envs:
        t = t.strip().lower()
        if not t:
            continue
        if t in name_lower or (env_tag and t in env_tag):
            return True
    return False


def lambda_handler(event, context):
    SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
    if not SNS_TOPIC_ARN:
        return {'statusCode': 500, 'body': json.dumps({'error': 'SNS_TOPIC_ARN not configured'})}
    target_envs_raw = os.environ.get('TARGET_ENVIRONMENTS', 'dev,development')
    target_envs = [s.strip() for s in target_envs_raw.split(',') if s.strip()] if target_envs_raw else []
    try:
        clusters_response = eks_client.list_clusters()
        cluster_names = clusters_response.get('clusters', [])
        all_results = []
        for cluster_name in cluster_names:
            try:
                cluster_response = eks_client.describe_cluster(name=cluster_name)
                cluster = cluster_response.get('cluster', {})
                cluster_tags = cluster.get('tags', {})
                cluster_k8s_version = cluster.get('version')
                if not cluster_matches_target_environments(cluster_name, cluster_tags, target_envs):
                    continue
                results = process_cluster_nodegroups(cluster_name, cluster_k8s_version, SNS_TOPIC_ARN)
                all_results.append({'cluster': cluster_name, 'status': 'processed', 'nodegroups': results})
            except ClientError as e:
                all_results.append({'cluster': cluster_name, 'status': 'error', 'error': str(e)})
        return {'statusCode': 200, 'body': json.dumps({'message': 'Node group processing completed', 'clusters_processed': len(all_results), 'results': all_results})}
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
