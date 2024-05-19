const scriptLocation = "/usr/local/echopilot/scripts/"
const confLocation = "/usr/local/echopilot/mavnetProxy/"
const apn = document.getElementById("apn");
const CONFIG_LENGTH = 1;

// Runs the initPage when the document is loaded
document.onload = InitPage();
// Save file button
document.getElementById("save").addEventListener("click", SaveSettings);

// This attempts to read the conf file, if it exists, then it will parse it and fill out the table
// if it fails then the values are loaded with defaults.
function InitPage() {
    
    cockpit.script(scriptLocation + "cockpitScript.sh -c")
                .then((content) => SuccessReadFile(content))
                .catch(error => FailureReadFile(error));
    
}

function SuccessReadFile(content) {
    try{
        if(content.length > 0) {
            apn.value = content;
        }
        else{
            FailureReadFile(new Error("Not APN found"));
        }
    }
    catch(e){
        FailureReadFile(e);
    }
}

function FailureReadFile(error) {
    // Display error message
    output.innerHTML = "Error : " + error.message;
    // TODO :: Defaults should go here.

    apn.value = "broadband";
}

// The callback on the enable button
function EnableButtonClicked() {
    if(enabled == false) {
        EnableService();
    }
    else{
        DisableService();
    }
}

function SaveSettings() {
    console.log("Updating apn value to "+ apn.value);
    cockpit.script(scriptLocation + "cockpitScript.sh -a " + apn.value);
    result.style.color = "green";
    result.innerHTML = "Success, restarting cellular...";
    setTimeout(() => result.innerHTML = "", 4000);
}

function Success() {
    result.style.color = "green";
    result.innerHTML = "success";
}

function Fail(error) {
    result.style.color = "red";
    result.innerHTML = error.message;
}
// Send a 'init' message.  This tells integration tests that we are ready to go
cockpit.transport.wait(function() { });
