# Robot tests guidelines

## Good practices

- Test case and keywords names shouldn't be more than 40 character. Having too long names may seem to increase
  description, but they actually reduce readability. Use the Documentation tag for more details

- Documentation should always be filled. A Documentation line shouldn't be longer than 80 characters. Multiple lines is
  preferred to long lines. The start of each line should be aligned.

- Tags should only be used to describe the requirements to run a test. It should not be used for description. Use
  Documentation for that. 2 spaces should separate each tags.

- An empty line should separate the Documentation/Tags section from the instructions section. You may remove this empty
  line in case of single line test cases, if it increases readability.

- The instructions should be organized in three columns. Each column start should be aligned. A column shouldn't be more
  than 30 characters and 4 spaces should separate each column. Depending on whether you're executing an action or
  assigning a variable, the columns should follow this organization :

```
  # Action                 # Arguments            # Arguments                   
  # Variable               # Action               # Arguments
```

- In case of short arguments name or values, you may put multiple arguments in a column. But keep in mind that multiple
  aligned lines are more readable than a single long one.


- Multiline actions should use less than 5 lines. In case you need to use more, consider using keywords to increase
  readability. A test case should be short and easily understandable.

## Examples

```robot
*** Keywords ***
Post To Gateway
    [Documentation]  HTTP POST on gateway session
    [Arguments]  ${url}  ${expected_status}=200  &{config}

    ${response}=      POST On Session    gateway    ${url}    
    ...                                  expected_status=${expected_status}    
    ...                                  &{config}
    [Return]          ${response}


*** Test Cases ***
Punchlet Execution Through Gateway
    [Documentation]  Execute a punchlet through gateway.
    ...              Get punchlet resources and send a POST Request.
    [Tags]  gateway  punchlet

    ${punchlet_input}=    Get Binary File         ${resources}/punchlet/input
    ${punchlet_log}=      Get Binary File         ${resources}/punchlet/punchlet
    &{data}=              Create Dictionary       input=${punchlet_input}
    ...                                           logFile=${punchlet_log}
    Post To Gateway       /v1/puncher/punchlet    files=&{data}
```

