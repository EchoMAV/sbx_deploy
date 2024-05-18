const scriptLocation = "/usr/local/echopilot/scripts/"
const confLocation = "/usr/local/echopilot/mavnetProxy/"
const version = document.getElementById("version");
const file_location = document.getElementById("file_location");
const losHost = document.getElementById("losHost");
const losPort = document.getElementById("losPort");
const losIface = document.getElementById("losIface");
const fmuDevice = document.getElementById("fmuDevice");
const baudrate = document.getElementById("baudrate");
const fmuId = document.getElementById("fmuId");
const atakHost = document.getElementById("atakHost");
const atakPort = document.getElementById("atakPort");
const fmuConnStatus = document.getElementById("fmuConnStatus");
const CONFIG_LENGTH = 11;
// standard Baud rates
const baudRateArray = [ 38400, 57600, 115200, 230400, 460800, 500000, 921600 ];

enabled = true;
// Runs the initPage when the document is loaded
document.onload = InitPage();

// Save file button
document.getElementById("save").addEventListener("click", SaveSettings);

// This attempts to read the conf file, if it exists, then it will parse it and fill out the table
// if it fails then the values are loaded with defaults.
function InitPage() {

    file_location.innerHTML = confLocation + "mavnetProxy.conf";

    cockpit.file(confLocation + "mavnetProxy.conf")
        .read().then((content, tag) => SuccessReadFile(content))
            .catch(error => FailureReadFile(error));
    cockpit.script(scriptLocation + "cockpitScript.sh -v")
    .then((content) => version.innerHTML=content)
    .catch(error => Fail("script -v", error));    
    
    cockpit.script(scriptLocation + "cockpitScript.sh -u")
    .then(function(content) {
        ipsubnet1.innerHTML=content;        
    })
    .catch(error => Fail(error));  

    cockpit.script(scriptLocation + "cockpitScript.sh -t")
    .then(function(content) {
        fmuStatus(content.trim());    
    })
    .catch(error => Fail(error));  

    setInterval(fmuStatusTimer, 3000);
}

function fmuStatusTimer() {
    cockpit.script(scriptLocation + "cockpitScript.sh -t")
    .then(function(content) {
        console.log ("got status of " + content);
        fmuStatus(content.trim());    
    })
    .catch(error => Fail(error));  
}

function fmuStatus(content)
{
    if (content === "true") {
        fmuConnStatus.innerHTML = "Connected, Receiving Data";
        fmuConnStatus.style.color = 'green';
    }
    else if (content === "false") {
        fmuConnStatus.innerHTML = "Not Connected, Check Settings Below";
        fmuConnStatus.style.color = 'red';
    }
    else {        
        fmuConnStatus.innerHTML = "Service Error, Not Connected";
        fmuConnStatus.style.color = 'red';
    }   
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
               
        //console.log("success reading file " + myConfig.FMU_SERIAL);
        if(myConfig.TELEM_LOS != "") {
            cockpit.script(scriptLocation + "cockpitScript.sh -s")                
                .then((content) => AddDropDown(fmuDevice, content.trim().split("\n"), myConfig.FMU_SERIAL)) 
                .catch(error => Fail("Get Serial", error));
            AddDropDown(baudrate, baudRateArray, myConfig.FMU_BAUDRATE);
            fmuId.value = myConfig.FMU_SYSID
            losHost.value = myConfig.TELEM_LOS.split(",")[1].split(":")[0];
            losPort.value = myConfig.TELEM_LOS.split(",")[1].split(":")[1];
            cockpit.script(scriptLocation + "cockpitScript.sh -i")
                .then((content) => AddDropDown(losIface, content.trim().split("\n"), myConfig.TELEM_LOS.split(",")[0]))
                .catch(error => Fail("2", error));      
            atakHost.value = myConfig.ATAK_HOST;
            atakPort.value = myConfig.ATAK_PORT;
        }
        else{
            FailureReadFile(new Error("Too few parameters in file"));
        }
    }
    catch(e){
        FailureReadFile(e);
    }

}

function AddPathToDeviceFile(incomingArray){
    for(let t = 0; t < incomingArray.length; t++){
        incomingArray[t] = "/dev/" + incomingArray[t];
    }
    return incomingArray;
}

function AddDropDown(box, theArray, defaultValue){
    try{    
        for(let t = 0; t < theArray.length; t++){
            var option = document.createElement("option");
            option.text = theArray[t];
            box.add(option);
            if(defaultValue == option.text){
                box.value = option.text;
            }
        }
    }
    catch(e){
        Fail("Dropdown", e)
    }
}

function FailureReadFile(error) {
    // Display error message
    output.innerHTML = "Error : " + error.message;
    losHost.value = "172.20.1.1";
    losPort.value = "14550";
    fmuId.value = "1";
    atakHost.value = "239.2.3.1";
    atakPort.value = "6969";       
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

// If we are enabling the service (either for the first time or not)
//not currently used
function EnableService(){
    enabled = true;
    
    var fileString = "[Service]\n" + 
        "FMU_SERIAL=" + fmuDevice.value + "\n" +
        "FMU_BAUDRATE=" + baudrate.value + "\n" +
        "FMU_SYSID=" + fmuId.value + "\n" +
        "LOS_HOST=" + losHost.value + "\n" +
        "LOS_PORT=" + losPort.value + "\n" +
        "LOS_IFACE=" + losIface.value + "\n" +
        "ATAK_HOST=" + atakHost.value + "\n" +
        "ATAK_PORT=" + atakPort.value + "\n" +
        "ENABLED=" + enabled.toString() + "\n";

    cockpit.file(confLocation + "mavnetProxy.conf").replace(fileString)
        .then(CreateSystemDService).catch(error => {output.innerHTML = error.message});
}

function CreateSystemDService(){
    // copy the the service over
    cockpit.spawn(["cp", "-rf", "/usr/local/share/h31proxy_deploy/h31proxy.service", "/lib/systemd/system/"]);
    // make ln for multi-user
    cockpit.spawn(["ln", "-sf", "/etc/systemd/system/h31proxy.service", "/etc/systemd/system/multi-user.target.wants/h31proxy.service"]);
}

// When disable is pressed we need to re write the conf file to 
// make sure the enabled feature is false and also remove
// the service files so they will not start up again
// not currently used
function DisableService(){
    enabled = false;
    

    var fileString = "[Service]\n" + 
        "FMU_SERIAL=" + fmuDevice.value + "\n" +
        "FMU_BAUDRATE=" + baudrate.value + "\n" +
        "FMU_SYSID=" + fmuId.value + "\n" +
        "LOS_HOST=" + losHost.value + "\n" +
        "LOS_PORT=" + losPort.value + "\n" +
        "LOS_IFACE=" + losIface.value + "\n" +
        //"BACKUP_HOST=" + backupHost.value + "\n" +
        //"BACKUP_PORT=" + backupPort.value + "\n" +
        //"BACKUP_IFACE=" + backupIface.value + "\n" +
        "ATAK_HOST=" + atakHost.value + "\n" +
        "ATAK_PORT=" + atakPort.value + "\n" +
        "ENABLED=" + enabled.toString() + "\n";

    cockpit.file(confLocation + "h31proxy.conf").replace(fileString)
        .then(RemoveSystemLinks).catch(error => {output.innerHTML = error.message});
}

// removes the links
function RemoveSystemLinks(){
    // remove the service file
    cockpit.spawn(["rm", "-rf", "/lib/systemd/system/h31proxy.service"]);
    // remove ln for multi-user
    cockpit.spawn(["rm", "-rf", "/etc/systemd/system/multi-user.target.wants/h31proxy.service"]);
    result.innerHTML = "Removed Serivce files";
}

function SaveSettings() {
   //lets do some validation
        
   var ipformat = /^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
   var portformat = /^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$/;
   var errorFlag = false;
   var errorText = "";
   if (!losHost.value.match(ipformat)) {
       losHost.focus();
       errorText += "Error in the Host Address!<br>";
       errorFlag = true;
   }
   if (!losPort.value.match(portformat)) {
       losPort.focus();
       errorText += "Error in the Port Number! (0-65535 allowed)<br>";
       errorFlag = true;
   }
   
   if (errorFlag)
   {
       result.style.color = "red";
       result.innerHTML = errorText;
       return;
   }

   var fileString = 
       "TELEM_LOS=" + losIface.value + ","+ losHost.value + ":" + losPort.value + "\n" +
       "FMU_SERIAL=" + fmuDevice.value + "\n" +
       "FMU_BAUDRATE=" + baudrate.value + "\n" +
       "FMU_SYSID=" + fmuId.value + "\n" +        
       "ATAK_HOST=" + atakHost.value + "\n" +
       "ATAK_PORT=" + atakPort.value + "\n";       

   cockpit.file(confLocation + "mavnetProxy.conf", { superuser : "try" }).replace(fileString)
       .then(Success)
       .catch(Fail);
 
   cockpit.spawn(["systemctl", "restart", "mavnetProxy"]);   
}

function Success() {
    result.style.color = "green";
    result.innerHTML = "Success, restarting Telemetry Services...";
    setTimeout(() => result.innerHTML = "", 4000);
}

function Fail(source, error) {
    result.style.color = "red";
    result.innerHTML = error.message;
    console.log(source + ": " + error.message);
}
// Send a 'init' message.  This tells integration tests that we are ready to go
cockpit.transport.wait(function() { });
