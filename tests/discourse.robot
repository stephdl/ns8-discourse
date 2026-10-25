*** Settings ***
Library    SSHLibrary

*** Variables ***
${ADMIN_USER}        admin
${ADMIN_PASSWORD}    Nethesis,1234
${SCENARIO}          install
# Any resolvable-looking name: the schema demands a dot, nothing resolves it.
${TEST_HOST}    discourse.ns8-ci.test
${ADMIN}        "admin_email":"admin@ns8-ci.test","admin_username":"ns8admin","default_locale":"en","oidc_enabled":false

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${ADMIN_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${ADMIN_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=30s

Enable the stephdl forge
    # The module is published there, not in the default NS8 repositories.
    ${rc} =    Execute Command
    ...    api-cli run add-repository --data '{"name":"stephdl","url":"https://forge.de-labrusse.fr/ns8/updates/","status":true}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Discourse answers
    ${output}  ${rc} =    Execute Command    curl -sk -o /dev/null -w '\%{http_code}' --resolve ${TEST_HOST}:443:127.0.0.1 https://${TEST_HOST}/srv/status
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Be Equal    ${output}    200

The admin account is stored
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgresql-app psql -U discourse -d discourse -tAc "SELECT admin FROM users WHERE username = 'ns8admin'"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Be Equal    ${output}    t

*** Test Cases ***
Check if discourse is installed correctly
    # The update scenario starts from the release published in the stephdl forge,
    # then upgrades it to the image under test through update-module below.
    IF    '${SCENARIO}' == 'update'
        Enable the stephdl forge
        ${image} =    Set Variable    discourse
    ELSE
        ${image} =    Set Variable    ${IMAGE_URL}
    END
    ${output}  ${rc} =    Execute Command    add-module ${image} 1
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
    Set Suite Variable    ${discourse_password}    ${password}
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
    Discourse answers

Check if the admin account is created
    Wait Until Keyword Succeeds    30 times    10 seconds    The admin account is stored

Check if a reconfigure without password is accepted
    ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"host":"${TEST_HOST}","lets_encrypt":false,${ADMIN}}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Update discourse to the image under test
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}, nothing to update
    ${rc} =    Execute Command
    ...    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check discourse works after the update
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}, nothing to update
    # Discourse migrates its database on start, which can take a few minutes.
    Wait Until Keyword Succeeds    60 times    10 seconds    Discourse answers
    ${output}  ${rc} =    Execute Command    api-cli run module/${module_id}/get-configuration --data '{}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    ${config} =    Evaluate    json.loads('''${output}''')    modules=json
    Should Be Equal    ${config}[host]    ${TEST_HOST}
    Should Be True    ${config}[admin_password_set]

Check the admin account survives the update
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}, nothing to update
    The admin account is stored

Take screenshots
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True
    Login to cluster-admin
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> h2 >> text="Status"    visible    timeout=30s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> h2 >> text="Settings"    visible    timeout=30s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
    Close Browser

Check if discourse is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
