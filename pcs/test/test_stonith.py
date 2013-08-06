import os,sys
import shutil
import unittest
parentdir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0,parentdir) 
import utils
from pcs_test_functions import pcs,ac

empty_cib = "empty.xml"
temp_cib = "temp.xml"

class StonithTest(unittest.TestCase):
    def setUp(self):
        shutil.copy(empty_cib, temp_cib)

    def testStonithCreation(self):
        output, returnVal = pcs(temp_cib, "stonith create test1 fence_noxist")
        assert returnVal == 1
        assert output == "Error: Unable to create resource 'stonith:fence_noxist', it is not installed on this system (use --force to override)\n"

        output, returnVal = pcs(temp_cib, "stonith create test1 fence_noxist --force")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith create test2 fence_ilo")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith create test3 fence_ilo bad_argument=test")
        assert returnVal == 1
        assert output == "Error: resource option(s): 'bad_argument', are not recognized for resource type: 'stonith:fence_ilo' (use --force to override)\n",[output]

        output, returnVal = pcs(temp_cib, "stonith create test3 fence_ilo ipaddr=test")
        assert returnVal == 0
        assert output == "",[output]

# Testing that pcmk_host_check, pcmk_host_list & pcmk_host_map are allowed for
# stonith agents
        output, returnVal = pcs(temp_cib, 'stonith create apc-fencing fence_apc params ipaddr="morph-apc" login="apc" passwd="apc" switch="1" pcmk_host_map="buzz-01:1;buzz-02:2;buzz-03:3;buzz-04:4;buzz-05:5" action="reboot" debug="1" pcmk_host_check="static-list" pcmk_host_list="buzz-01,buzz-02,buzz-03,buzz-04,buzz-05"')
        assert returnVal == 0
        assert output == "",[output]

        output, returnVal = pcs(temp_cib, 'resource show apc-fencing')
        assert returnVal == 1
        assert output == 'Error: unable to find resource \'apc-fencing\'\n',[output]

        output, returnVal = pcs(temp_cib, 'stonith show apc-fencing')
        assert returnVal == 0
        assert output == ' Resource: apc-fencing (class=stonith type=fence_apc)\n  Attributes: ipaddr="morph-apc" login="apc" passwd="apc" switch="1" pcmk_host_map="buzz-01:1;buzz-02:2;buzz-03:3;buzz-04:4;buzz-05:5" action="reboot" debug="1" pcmk_host_check="static-list" pcmk_host_list="buzz-01,buzz-02,buzz-03,buzz-04,buzz-05" \n  Operations: monitor interval=60s (apc-fencing-monitor-interval-60s)\n',[output]

        output, returnVal = pcs(temp_cib, 'stonith delete apc-fencing')
        assert returnVal == 0
        assert output == 'Deleting Resource - apc-fencing\n',[output]

        output, returnVal = pcs(temp_cib, "stonith update test3 bad_ipaddr=test")
        assert returnVal == 1
        assert output == "Error: resource option(s): 'bad_ipaddr', are not recognized for resource type: 'stonith::fence_ilo' (use --force to override)\n",[output]

        output, returnVal = pcs(temp_cib, "stonith update test3 login=testA")
        assert returnVal == 0
        assert output == "",[output]

        output, returnVal = pcs(temp_cib, "stonith show test2")
        assert returnVal == 0
        assert output == " Resource: test2 (class=stonith type=fence_ilo)\n  Operations: monitor interval=60s (test2-monitor-interval-60s)\n",[output]

        output, returnVal = pcs(temp_cib, "stonith show --all")
        assert returnVal == 0
        assert output == " Resource: test1 (class=stonith type=fence_noxist)\n  Operations: monitor interval=60s (test1-monitor-interval-60s)\n Resource: test2 (class=stonith type=fence_ilo)\n  Operations: monitor interval=60s (test2-monitor-interval-60s)\n Resource: test3 (class=stonith type=fence_ilo)\n  Attributes: ipaddr=test login=testA \n  Operations: monitor interval=60s (test3-monitor-interval-60s)\n",[output]

        output, returnVal = pcs(temp_cib, 'stonith create test-fencing fence_apc pcmk_host_list="rhel7-node1 rhel7-node2" op monitor interval=61s')
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, 'config show')
        assert returnVal == 0
        assert output == 'Cluster Name: test99\nCorosync Nodes:\n rh7-1 rh7-2 \nPacemaker Nodes:\n \n\nResources: \n\nStonith Devices: \n Resource: test1 (class=stonith type=fence_noxist)\n  Operations: monitor interval=60s (test1-monitor-interval-60s)\n Resource: test2 (class=stonith type=fence_ilo)\n  Operations: monitor interval=60s (test2-monitor-interval-60s)\n Resource: test3 (class=stonith type=fence_ilo)\n  Attributes: ipaddr=test login=testA \n  Operations: monitor interval=60s (test3-monitor-interval-60s)\n Resource: test-fencing (class=stonith type=fence_apc)\n  Attributes: pcmk_host_list="rhel7-node1 \n  Operations: monitor interval=61s (test-fencing-monitor-interval-61s)\nFencing Levels: \n\nLocation Constraints:\nOrdering Constraints:\nColocation Constraints:\n\nCluster Properties:\n',[output]

    def testStonithFenceConfirm(self):
        output, returnVal = pcs(temp_cib, "stonith fence blah blah")
        assert returnVal == 1
        assert output == "Error: must specify one (and only one) node to fence\n"

        output, returnVal = pcs(temp_cib, "stonith confirm blah blah")
        assert returnVal == 1
        assert output == "Error: must specify one (and only one) node to confirm fenced\n"

    def testPcmkHostList(self):
        output, returnVal = pcs(temp_cib, "stonith create F1 fence_apc 'pcmk_host_list=nodea nodeb'")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith show F1")
        assert returnVal == 0
        assert output == ' Resource: F1 (class=stonith type=fence_apc)\n  Attributes: pcmk_host_list="nodea nodeb" \n  Operations: monitor interval=60s (F1-monitor-interval-60s)\n',[output]

    def testFenceLevels(self):
        output, returnVal = pcs(temp_cib, "stonith level remove 1 rh7-2 F1")
        assert returnVal == 1
        ac (output,'Error: unable to remove fencing level, fencing level for node: rh7-2, at level: 1, with device: F1 doesn\'t exist\n')

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith create F1 fence_apc 'pcmk_host_list=nodea nodeb'")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith create F2 fence_apc 'pcmk_host_list=nodea nodeb'")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith create F3 fence_apc 'pcmk_host_list=nodea nodeb'")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith create F4 fence_apc 'pcmk_host_list=nodea nodeb'")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith create F5 fence_apc 'pcmk_host_list=nodea nodeb'")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level add 1 rh7-1 F3,F4")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level add 2 rh7-1 F5,F2")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level add 2 rh7-1 F5,F2")
        assert returnVal == 1
        assert output == 'Error: unable to add fencing level, fencing level for node: rh7-1, at level: 2, with device: F5,F2 already exists\n',[output]

        output, returnVal = pcs(temp_cib, "stonith level add 1 rh7-2 F1")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level add 2 rh7-2 F2")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith show")
        assert returnVal == 0
        ac(output,' F1\t(stonith:fence_apc):\tStopped \n F2\t(stonith:fence_apc):\tStopped \n F3\t(stonith:fence_apc):\tStopped \n F4\t(stonith:fence_apc):\tStopped \n F5\t(stonith:fence_apc):\tStopped \n Node: rh7-1\n  Level 1 - F3,F4\n  Level 2 - F5,F2\n Node: rh7-2\n  Level 1 - F1\n  Level 2 - F2\n')

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-1\n  Level 1 - F3,F4\n  Level 2 - F5,F2\n Node: rh7-2\n  Level 1 - F1\n  Level 2 - F2\n',[output]

        output, returnVal = pcs(temp_cib, "stonith level remove 1 rh7-2 F1")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level remove 1 rh7-2 F1")
        assert returnVal == 1
        assert output == 'Error: unable to remove fencing level, fencing level for node: rh7-2, at level: 1, with device: F1 doesn\'t exist\n',[output]

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-1\n  Level 1 - F3,F4\n  Level 2 - F5,F2\n Node: rh7-2\n  Level 2 - F2\n',[output]
        
        output, returnVal = pcs(temp_cib, "stonith level clear rh7-1a")
        assert returnVal == 0
        output = ""

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-1\n  Level 1 - F3,F4\n  Level 2 - F5,F2\n Node: rh7-2\n  Level 2 - F2\n',[output]
        
        output, returnVal = pcs(temp_cib, "stonith level clear rh7-1")
        assert returnVal == 0
        output = ""

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-2\n  Level 2 - F2\n',[output]
        
        output, returnVal = pcs(temp_cib, "stonith level add 2 rh7-1 F5,F2")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level add 1 rh7-1 F3,F4")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-1\n  Level 1 - F3,F4\n  Level 2 - F5,F2\n Node: rh7-2\n  Level 2 - F2\n',[output]
        
        output, returnVal = pcs(temp_cib, "stonith level clear")
        assert returnVal == 0
        assert output == ""

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == '',[output]

        output, returnVal = pcs(temp_cib, "stonith level 1")
        assert returnVal == 1
        ac (output,"pcs stonith level: invalid option -- '1'\n\nUsage: pcs stonith s...\n    show [stonith id]\n        Show all currently configured stonith devices or if a stonith id is\n        specified show the options for the configured stonith device.  If\n        --all is specified all configured stonith options will be displayed\n\n")

        output, returnVal = pcs(temp_cib, "stonith level abcd")
        assert returnVal == 1
        assert output == "pcs stonith level: invalid option -- 'abcd'\n\nUsage: pcs stonith s...\n    show [stonith id]\n        Show all currently configured stonith devices or if a stonith id is\n        specified show the options for the configured stonith device.  If\n        --all is specified all configured stonith options will be displayed\n\n",[output]

        output, returnVal = pcs(temp_cib, "stonith level add 1 rh7-1 blah")
        assert returnVal == 1
        assert output == 'Error: blah is not a stonith id (use --force to override)\n'

        output, returnVal = pcs(temp_cib, "stonith level add 1 rh7-1 blah --force")
        assert returnVal == 0
        assert output == ''

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-1\n  Level 1 - blah\n',[output]

        output, returnVal = pcs(temp_cib, "stonith level add 1 rh7-9 F1")
        assert returnVal == 1
        assert output == 'Error: rh7-9 is not currently a node (use --force to override)\n'

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-1\n  Level 1 - blah\n',[output]

        output, returnVal = pcs(temp_cib, "stonith level add 1 rh7-9 F1 --force")
        assert returnVal == 0
        assert output == ''

        output, returnVal = pcs(temp_cib, "stonith level")
        assert returnVal == 0
        assert output == ' Node: rh7-1\n  Level 1 - blah\n Node: rh7-9\n  Level 1 - F1\n',[output]

if __name__ == "__main__":
    unittest.main()

