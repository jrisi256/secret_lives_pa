# Troubleshooting technical issues in getting RSelenium working

When attempting to run `rsDriver()` for the first time, I would get the following error message `Error in wdman::selenium(port = port, verbose = verbose, version = version, :
Selenium server couldn't be started`.

I found the following [github link](https://github.com/ropensci/RSelenium/issues/264#issuecomment-1344003384) which helped me solve the issue.

Specifically running the below command fixed the issue.

``` R
wdman::selenium(retcommand = T)
```

After fixing this issue, another new issue popped up: `Could not open firefox browser. Client error message: undefined error in httr call. httr output: Failed to connect to localhost port 4544 after 0 ms: Connection refused Check server log for further details. Warning message: In rsDrive (browser = web_browser, port = 4544L) : Could not determine server status.`

Thankfully, this [Github link](https://github.com/ropensci/RSelenium/issues/266) and [Stack Overflow link](https://stackoverflow.com/questions/45395849/cant-execute-rsdriver-connection-refused/74735571#74735571) pointed me in the right direction. To fix the issue, you need to include `chromever = NULL` in you `rsDriver()` function call.
