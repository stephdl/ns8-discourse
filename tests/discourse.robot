*** Settings ***
Library    SSHLibrary

*** Variables ***
# Any resolvable-looking name: the schema demands a dot, nothing resolves it.
${TEST_HOST}    discourse.ns8-ci.test
${ADMIN}        "admin_email":"admin@ns8-ci.test","admin_username":"ns8admin","default_locale":"en","oidc_enabled":false

*** Test Cases ***
Check if discourse is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if a missing admin password is rejected
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false,${ADMIN}}'
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0

Check if a weak admin password is rejected
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false,${ADMIN},"admin_password":"Short-1"}'
    ...    return_rc=True  return_stdout=False
    Should Not Be Equal As Integers    ${rc}  0

Check if discourse can be configured
    ${password} =    Evaluate    secrets.token_urlsafe(16) + "-Aa1!"    modules=secrets
    Set Suite Variable    ${admin_password}    ${password}
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false,${ADMIN},"admin_password":"${password}"}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if discourse configuration reads back
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${config} =    Evaluate    json.loads('''${output}''')    modules=json
    Should Be Equal    ${config}[host]    ${TEST_HOST}
    Should Be True    ${config}[admin_password_set]

Check if discourse answers through Traefik
    ${output}  ${rc} =    Execute Command    curl -sk -o /dev/null -w '\%{http_code}' --resolve ${TEST_HOST}:443:127.0.0.1 https://${TEST_HOST}/srv/status
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Be Equal    ${output}    200

Check if a reconfigure without password is accepted
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false,${ADMIN}}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if discourse is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
