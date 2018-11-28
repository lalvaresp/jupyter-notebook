import json
import subprocess
import sys

command = 'curl --user {ambari_user}:{ambari_password} -H ' \
          '"X-Requested-By: ambari" -X GET {ambari_host}/api/v1/clusters/' \
          '{cluster_name}/services/HDFS/components/DATANODE'.format(
            ambari_user=sys.argv[1], ambari_password=sys.argv[2],
            ambari_host=sys.argv[3], cluster_name=sys.argv[4]
          )
proc = subprocess.Popen(
    command.split(),
    stdout=subprocess.PIPE)
(out, err) = proc.communicate()
json_result = json.loads(out)

slaves = []
for host in json_result.get('host_components', []):
    slaves.append(host.get('HostRoles', {})['host_name'])

f = open('/usr/hdp/current/hadoop-client/conf/slaves', 'w')
f.write('\n'.join(slaves))
f.close()
