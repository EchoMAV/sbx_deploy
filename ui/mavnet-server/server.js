const confLocation = "/usr/local/echopilot/mavnetProxy/"
const serialNum = document.getElementById("serialNum");
const deviceTok = document.getElementById("deviceTok");
const serverUrl = document.getElementById("serverUrl");

const CONFIG_LENGTH = 3;

// Save file button
document.getElementById("save").addEventListener("click", SaveSettings);

document.onload = InitPage();

function InitPage() {
    cockpit.file(confLocation + "mavnet.conf").read().then((content, tag) => SuccessReadFile(content))
    .catch(error => FailureReadFile(error));
}

function SuccessReadFile(content) {
    try{

        var lines = content.split('\n');
        var myConfig = {};
        for(var line = 0; line < lines.length; line++){
            
            if (lines[line].trim().startsWith("#") === false)  //check if this line in the config file is not commented out
            {
                var currentline = lines[line].split('=');
                
                if (currentline.length === 2)            
                    myConfig[currentline[0].trim().replace(/["]/g, "")] = currentline[1].trim().replace(/["]/g, "");  
            }          
        }       
        var splitResult = content.split("\n");
        
        if(splitResult.length >= CONFIG_LENGTH) {
            serverUrl.value = myConfig.SERVER_ADDRESS;
            deviceTok.value = myConfig.DEVICE_TOKEN;
            serialNum.value = myConfig.SERIAL_NUMBER;
        }
        else{
            FailureReadFile(new Error("To few parameters in file"));
        }
    }
    catch(e){
        FailureReadFile(e);
    }
}

function FailureReadFile(error) {
    // Display error message
    output.innerHTML = "Error : " + error.message;

    // Defaults
    serialNum.value = "123456789";
    deviceTok.value = "";
    serverUrl.value = "https://gcs.echomav.com";

}

function SaveSettings() {

    cockpit.file(confLocation + "mavnet.conf").replace("[Service]\n" + 
    "SERVER_ADDRESS=" + serverUrl.value + "\n" +   
    "SERIAL_NUMBER=" + serialNum.value + "\n" +
    "DEVICE_TOKEN=" + deviceTok.value + "\n")
        
        .then(Success)
        .catch(Fail);

    cockpit.spawn(["systemctl", "restart", "mavnetProxy"]);
}

function Success() {
    result.style.color = "green";
    result.innerHTML = "Success, restarting Telemetry Services...";
    setTimeout(() => result.innerHTML = "", 4000);
}

function Fail() {
    result.style.color = "red";
    result.innerHTML = "fail";
}

// Send a 'init' message.  This tells integration tests that we are ready to go
cockpit.transport.wait(function() { });
