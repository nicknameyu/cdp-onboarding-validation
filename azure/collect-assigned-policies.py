#!/usr/bin/python3
# Version 0.1.1

# Description: the script is used to collect the policy and initiative assignmented to the subscription and the management groups where the subscription
#              belongs to for future assesment.
# supported os: MacOS, Linux, or a Windows OS with a bash environment.
# usage: 
#   1. Login azure cli
#   2. set context to the subscritpion you want to exam.
#   3. run: python3 ./collect-assigned-policies.py
#   4. send the generated assigned-policies.tar.gz to CSA for review.

import os
import subprocess
import json
ret, val = subprocess.getstatusoutput("az account show")
if ret > 0:
    print("FATAL: Failed getting policy assignments. Please check error message for detail. ")
    print(val)
    exit(1)
subscriptionId = json.loads(val)['id']

ret, val = subprocess.getstatusoutput("az policy assignment list --disable-scope-strict-match")
if ret > 0:
    print("FATAL: Failed getting policy assignments. Please check error message for detail. ")
    print(val)
    exit(1)

os.system("mkdir -p out")
file = open("./out/assignments.json", "w")
file.write(val)
file.close()

assignments = json.loads(val)
print("INFO: Collecting %d policy or initiatives. " % len(assignments) )
for x in assignments:
    if (x['scope'] != "/subscriptions/" + subscriptionId) and ("managementGroups" not in x['scope']):
        continue
    if "policyDefinition" in x['policyDefinitionId']:
        # this is a policy
        print("INFO: Collecting policy definition %s " % x['policyDefinitionId'])
        name = x['policyDefinitionId'].split("/")[-1]
        ret, val = subprocess.getstatusoutput("az policy definition show --name " + name)
        if ret > 0:
            print("ERROR: Failed getting policy definition \""+ x['policyDefinitionId'] + "\". Please check error message for detail. ")
            print(val)
        else:
            file = open("./out/policy-" + name + ".json", "w")
            file.write(val)
            file.close()
    else:
        # This is an initiative
        print("INFO: Collecting policies in initiative definition %s " % x['policyDefinitionId'])
        initName = x['policyDefinitionId'].split("/")[-1]
        ret, val = subprocess.getstatusoutput("az policy set-definition show --name " + initName)
        if ret > 0:
            print("ERROR: Failed getting policy definition \"" + x['policyDefinitionId'] + "\". Please check error message for detail. ")
            print(val)
        else:
            file = open("./out/init-" + initName + ".json", "w")
            file.write(val)
            file.close()
        initiative=json.loads(val)
        num = 1
        for policy in initiative['policyDefinitions']:
            print("INFO: Collecting number %d " % num + "policy in %d policies" % len(initiative['policyDefinitions']))
            num += 1
            name = policy['policyDefinitionId'].split("/")[-1]
            ret, val = subprocess.getstatusoutput("az policy definition show --name " + name)
            if ret > 0:
                print("ERROR: Failed getting policy definition \""+ policy['policyDefinitionId'] + "\". Please check error message for detail. ")
                print(val)
            else:
                file = open("./out/init-" + initName + "-policy-" + name + ".json", "w")
                file.write(val)
                file.close()


os.system("tar czvf assigned-policies.tar.gz ./out/*")
os.system("rm -rf ./out")