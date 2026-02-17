import boto3
import os
from typing import List, Dict, Optional


def get_next_version(current_version: str, available_versions: List[str]) -> Optional[str]:
    """Next incremental Kubernetes version. EKS upgrades one minor at a time."""
    try:
        current_parts = current_version.split('.')
        current_minor = int(current_parts[1])
        next_minor = current_minor + 1
        target_version = f"1.{next_minor}"
        if target_version in available_versions:
            return target_version
        return None
    except (IndexError, ValueError) as e:
        print(f"Error parsing version {current_version}: {str(e)}")
        return None


def get_cluster_addons(eks_client, cluster_name: str) -> List[Dict]:
    """List addons for a cluster with config (role, pod identity, etc.)."""
    addons = []
    try:
        list_response = eks_client.list_addons(clusterName=cluster_name)
        addon_names = list_response.get('addons', [])
        for addon_name in addon_names:
            try:
                describe_response = eks_client.describe_addon(
                    clusterName=cluster_name,
                    addonName=addon_name
                )
                addon_info = describe_response.get('addon', {})
                pod_identity_arns = addon_info.get('podIdentityAssociations', [])
                pod_identity_associations = None
                if pod_identity_arns:
                    pod_identity_associations = []
                    for assoc_arn in pod_identity_arns:
                        try:
                            assoc_response = eks_client.describe_pod_identity_association(
                                clusterName=cluster_name,
                                associationId=assoc_arn.split('/')[-1]
                            )
                            assoc_details = assoc_response.get('association', {})
                            pod_identity_associations.append({
                                'serviceAccount': assoc_details.get('serviceAccount'),
                                'roleArn': assoc_details.get('roleArn')
                            })
                        except Exception as e:
                            print(f"Error describing Pod Identity association {assoc_arn}: {str(e)}")
                            continue
                addon_dict = {
                    'addon_name': addon_info.get('addonName'),
                    'addon_version': addon_info.get('addonVersion'),
                    'service_account_role_arn': addon_info.get('serviceAccountRoleArn'),
                    'pod_identity_associations': pod_identity_associations,
                    'configuration_values': addon_info.get('configurationValues')
                }
                addons.append(addon_dict)
            except Exception as e:
                print(f"Error describing addon {addon_name} for cluster {cluster_name}: {str(e)}")
                continue
    except Exception as e:
        print(f"Error listing addons for cluster {cluster_name}: {str(e)}")
        return []
    return addons


def extract_auth_config(addon_info: Dict) -> Dict:
    """Auth config from addon: pod_identity, irsa, or none."""
    auth_config = {
        'auth_type': 'none',
        'service_account_role_arn': None,
        'pod_identity_associations': None
    }
    pod_identity_associations = addon_info.get('pod_identity_associations')
    if pod_identity_associations:
        auth_config['auth_type'] = 'pod_identity'
        auth_config['pod_identity_associations'] = pod_identity_associations
        return auth_config
    service_account_role_arn = addon_info.get('service_account_role_arn')
    if service_account_role_arn:
        auth_config['auth_type'] = 'irsa'
        auth_config['service_account_role_arn'] = service_account_role_arn
        return auth_config
    return auth_config


def parse_version(version_str: str) -> tuple:
    """Parse v1.15.0-eksbuild.1 into (major, minor, patch, build)."""
    if version_str.startswith('v'):
        version_str = version_str[1:]
    parts = version_str.split('-')
    version_part = parts[0]
    version_numbers = version_part.split('.')
    major = int(version_numbers[0]) if len(version_numbers) > 0 else 0
    minor = int(version_numbers[1]) if len(version_numbers) > 1 else 0
    patch = int(version_numbers[2]) if len(version_numbers) > 2 else 0
    build = 0
    if len(parts) > 1 and '.' in parts[1]:
        build_num = parts[1].split('.')[1]
        build = int(build_num) if build_num.isdigit() else 0
    return (major, minor, patch, build)


def compare_versions(version1: str, version2: str) -> str:
    """Return 'older', 'equal', or 'newer'."""
    try:
        v1_tuple = parse_version(version1)
        v2_tuple = parse_version(version2)
        if v1_tuple < v2_tuple:
            return 'older'
        if v1_tuple > v2_tuple:
            return 'newer'
        return 'equal'
    except (ValueError, IndexError) as e:
        print(f"Error comparing versions {version1} and {version2}: {str(e)}")
        return 'equal'


def check_addon_update_available(eks_client, cluster_name: str, addon_name: str,
                                  current_version: str, cluster_k8s_version: str) -> Optional[str]:
    """Latest addon version if update available, else None."""
    try:
        response = eks_client.describe_addon_versions(
            addonName=addon_name,
            kubernetesVersion=cluster_k8s_version
        )
        addon_versions = response.get('addons', [])
        if not addon_versions:
            return None
        addon_info = addon_versions[0]
        addon_version_infos = addon_info.get('addonVersions', [])
        if not addon_version_infos:
            return None
        latest_version = addon_version_infos[0].get('addonVersion')
        if not latest_version:
            return None
        if compare_versions(current_version, latest_version) == 'older':
            return latest_version
        return None
    except Exception as e:
        print(f"Error checking addon version for {addon_name}: {str(e)}")
        return None


def update_addon_with_auth_preservation(eks_client, cluster_name: str, addon_name: str,
                                         target_version: str, auth_config: Dict) -> Dict:
    """Update addon to target_version, keeping pod identity or IRSA."""
    try:
        update_params = {
            'clusterName': cluster_name,
            'addonName': addon_name,
            'addonVersion': target_version,
            'resolveConflicts': 'OVERWRITE'
        }
        auth_type = auth_config.get('auth_type', 'none')
        if auth_type == 'pod_identity':
            assocs = auth_config.get('pod_identity_associations')
            if assocs:
                update_params['podIdentityAssociations'] = assocs
        elif auth_type == 'irsa':
            role_arn = auth_config.get('service_account_role_arn')
            if role_arn:
                update_params['serviceAccountRoleArn'] = role_arn
        response = eks_client.update_addon(**update_params)
        update_id = response.get('update', {}).get('id')
        return {'success': True, 'update_id': update_id, 'error': None}
    except Exception as e:
        print(f"Error updating addon {addon_name}: {str(e)}")
        return {'success': False, 'update_id': None, 'error': str(e)}


def format_auth(auth_type):
    return {'pod_identity': 'Pod Identity', 'irsa': 'IRSA', 'none': 'None'}.get(auth_type, auth_type)


def send_cluster_addon_summary(sns_client, sns_topic_arn: str, cluster_name: str, addon_results: List[Dict]) -> None:
    """Send one SNS message with all addon results for the cluster."""
    if not addon_results:
        return
    up_to_date_count = sum(1 for a in addon_results if a['status'] == 'up_to_date')
    updated_count = sum(1 for a in addon_results if a['status'] == 'updated')
    failed_count = sum(1 for a in addon_results if a['status'] == 'failed')
    if failed_count > 0:
        subject = f"EKS Addon Summary - {cluster_name} - {failed_count} Failed"
    elif updated_count > 0:
        subject = f"EKS Addon Summary - {cluster_name} - {updated_count} Updated"
    else:
        subject = f"EKS Addon Summary - {cluster_name} - All Up-to-Date"
    message_parts = [
        f"Cluster: {cluster_name}",
        f"Total Addons: {len(addon_results)}",
        f"Up-to-Date: {up_to_date_count}",
        f"Updated: {updated_count}",
        f"Failed: {failed_count}",
        "", "=" * 60, ""
    ]
    if updated_count > 0:
        message_parts.append("UPDATED ADDONS:")
        message_parts.append("-" * 60)
        for addon in addon_results:
            if addon['status'] == 'updated':
                message_parts.extend([
                    f"  Addon: {addon['addon_name']}",
                    f"  Version: {addon['current_version']} -> {addon['target_version']}",
                    f"  Authentication: {format_auth(addon['auth_type'])}", ""
                ])
        message_parts.append("")
    if failed_count > 0:
        message_parts.append("FAILED ADDONS:")
        message_parts.append("-" * 60)
        for addon in addon_results:
            if addon['status'] == 'failed':
                message_parts.extend([
                    f"  Addon: {addon['addon_name']}",
                    f"  Current Version: {addon['current_version']}",
                    f"  Target Version: {addon.get('target_version', 'N/A')}",
                    f"  Authentication: {format_auth(addon['auth_type'])}",
                    f"  Error: {addon.get('error', 'Unknown error')}", ""
                ])
        message_parts.append("")
    if up_to_date_count > 0:
        message_parts.append("UP-TO-DATE ADDONS:")
        message_parts.append("-" * 60)
        for addon in addon_results:
            if addon['status'] == 'up_to_date':
                message_parts.append(f"  {addon['addon_name']} ({addon['current_version']}) - {format_auth(addon['auth_type'])}")
        message_parts.append("")
    try:
        sns_client.publish(TopicArn=sns_topic_arn, Subject=subject, Message="\n".join(message_parts))
    except Exception as e:
        print(f"Error sending addon summary for cluster {cluster_name}: {str(e)}")


def process_cluster_addons(eks_client, sns_client, cluster_name: str, cluster_k8s_version: str,
                           sns_topic_arn: str) -> List[Dict]:
    """Check and optionally update all addons; send one summary SNS."""
    import time
    results = []
    try:
        addons = get_cluster_addons(eks_client, cluster_name)
    except Exception as e:
        print(f"Failed to get addons for cluster {cluster_name}: {str(e)}")
        return results
    max_retries = 3
    for addon_info in addons:
        addon_name = addon_info.get('addon_name')
        current_version = addon_info.get('addon_version')
        addon_result = {
            'addon_name': addon_name, 'status': 'failed', 'current_version': current_version,
            'target_version': None, 'auth_type': 'none', 'error': None
        }
        try:
            auth_config = extract_auth_config(addon_info)
            addon_result['auth_type'] = auth_config.get('auth_type', 'none')
            latest_version = None
            for retry in range(max_retries):
                try:
                    latest_version = check_addon_update_available(
                        eks_client, cluster_name, addon_name, current_version, cluster_k8s_version)
                    break
                except Exception as e:
                    if 'ThrottlingException' in str(e) or 'TooManyRequestsException' in str(e):
                        if retry < max_retries - 1:
                            time.sleep(2 ** retry)
                        else:
                            raise
                    else:
                        raise
            if latest_version is None:
                addon_result['status'] = 'up_to_date'
                addon_result['target_version'] = current_version
            else:
                addon_result['target_version'] = latest_version
                update_result = None
                for retry in range(max_retries):
                    try:
                        update_result = update_addon_with_auth_preservation(
                            eks_client, cluster_name, addon_name, latest_version, auth_config)
                        break
                    except Exception as e:
                        if 'ThrottlingException' in str(e) or 'TooManyRequestsException' in str(e):
                            if retry < max_retries - 1:
                                time.sleep(2 ** retry)
                            else:
                                raise
                        else:
                            raise
                if update_result and update_result.get('success'):
                    addon_result['status'] = 'updated'
                else:
                    addon_result['status'] = 'failed'
                    addon_result['error'] = update_result.get('error') if update_result else 'Unknown error'
        except Exception as e:
            addon_result['status'] = 'failed'
            addon_result['error'] = str(e)
        results.append(addon_result)
    send_cluster_addon_summary(sns_client, sns_topic_arn, cluster_name, results)
    return results


def cluster_matches_target_environments(cluster_name: str, tags: Dict, target_envs: List[str]) -> bool:
    """True if target_envs is empty (all) or cluster name/tag contains one of the target strings."""
    if not target_envs:
        return True
    name_lower = cluster_name.lower()
    env_tag = (tags.get('Environment') or tags.get('environment') or tags.get('Env') or '').lower()
    for t in target_envs:
        t = t.strip().lower()
        if not t:
            continue
        if t in name_lower or (env_tag and t in env_tag):
            return True
    return False


def list_all_clusters(eks_client) -> List[str]:
    """List all cluster names (handles pagination)."""
    out = []
    next_token = None
    while True:
        kwargs = {}
        if next_token:
            kwargs['nextToken'] = next_token
        resp = eks_client.list_clusters(**kwargs)
        out.extend(resp.get('clusters', []))
        next_token = resp.get('nextToken')
        if not next_token:
            break
    return out


def lambda_handler(event, context):
    eks = boto3.client('eks')
    sns = boto3.client('sns')
    sns_topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not sns_topic_arn:
        return {'statusCode': 500, 'body': {'error': 'SNS_TOPIC_ARN not set'}}
    target_envs_raw = os.environ.get('TARGET_ENVIRONMENTS', 'dev,development')
    target_envs = [s.strip() for s in target_envs_raw.split(',') if s.strip()] if target_envs_raw else []
    clusters = list_all_clusters(eks)
    cluster_versions_response = eks.describe_cluster_versions()
    available_versions = [v['clusterVersion'] for v in cluster_versions_response.get('clusterVersions', [])]
    latest_available = available_versions[0] if available_versions else 'unknown'
    results = []
    for cluster_name in clusters:
        try:
            cluster_info = eks.describe_cluster(name=cluster_name)['cluster']
            current_version = cluster_info.get('version')
            tags = cluster_info.get('tags', {})
            if not cluster_matches_target_environments(cluster_name, tags, target_envs):
                continue
            cluster_result = {'cluster': cluster_name}
            next_version = get_next_version(current_version, available_versions) if current_version else None
            if not next_version:
                message = f"EKS cluster '{cluster_name}' is up to date\nCurrent version: {current_version}\nLatest available: {latest_available}"
                sns.publish(TopicArn=sns_topic_arn, Subject=f"EKS Cluster is up to date - {cluster_name}", Message=message)
                cluster_result['status'] = 'up_to_date'
            else:
                insights = eks.list_insights(clusterName=cluster_name, filter={'categories': ['UPGRADE_READINESS']})
                non_passing = [i for i in insights.get('insights', []) if i.get('insightStatus', {}).get('status') != 'PASSING']
                if non_passing:
                    message = f"EKS cluster '{cluster_name}' upgrade blocked: {len(non_passing)} failing insights\nCurrent version: {current_version}\nNext version: {next_version}"
                    sns.publish(TopicArn=sns_topic_arn, Subject=f"EKS Cluster Upgrade Blocked due to Potential Issue - {cluster_name}", Message=message)
                    cluster_result['status'] = 'blocked'
                    cluster_result['issues'] = len(non_passing)
                else:
                    if os.environ.get('ENABLE_AUTO_UPGRADE') == 'true':
                        eks.update_cluster_version(name=cluster_name, version=next_version)
                        message = f"EKS cluster '{cluster_name}' upgrade initiated: {current_version} -> {next_version}"
                        sns.publish(TopicArn=sns_topic_arn, Subject=f"EKS Cluster Upgrade Initiated - {cluster_name}", Message=message)
                        cluster_result['status'] = 'upgrading'
                    else:
                        message = f"EKS cluster '{cluster_name}' upgrade available: {current_version} -> {next_version}"
                        sns.publish(TopicArn=sns_topic_arn, Subject=f"EKS Cluster Upgrade Available for {cluster_name}", Message=message)
                        cluster_result['status'] = 'available'
            addon_results = process_cluster_addons(eks, sns, cluster_name, current_version or '', sns_topic_arn)
            cluster_result['addons'] = addon_results
            results.append(cluster_result)
        except Exception as e:
            print(f"Error processing cluster {cluster_name}: {e}")
            results.append({'cluster': cluster_name, 'status': 'error', 'error': str(e), 'addons': []})
    return {'statusCode': 200, 'body': {'processed_clusters': results}}
