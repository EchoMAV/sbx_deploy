
const confLocation = "/usr/local/echopilot/mavnetProxy/";
const scriptLocation = "/usr/local/echopilot/scripts/";
const losHost = document.getElementById("losHost");
const losPort = document.getElementById("losPort");
const losBitrate = document.getElementById("losBitrate");
//const atakHost = document.getElementById("atakHost");
//const atakPort = document.getElementById("atakPort");
//const atakIface = document.getElementById("atakIface");
//const atakBitrate = document.getElementById("atakBitrate");
const videoHost = document.getElementById("videoHost");
//const videoPort = document.getElementById("videoPort");
const videoBitrate = document.getElementById("videoBitrate");
const videoName = document.getElementById("videoName");
const myIP = document.getElementById("myIP");
const myIP2 = document.getElementById("myIP2");
const serverSection = document.getElementById("serverSection");
const noServerSection = document.getElementById("noServerSection");

// used for primary gcs bitrate
const losBitrateArray = [ "Disabled", "500", "750", "1000", "1250", "1500", "2000", "2500", "3000", "3500", "4000", "4500", "5000" ];


// used for mav, atak, and video
const serverBitrateArray = [ "Disabled", "500", "750", "1000", "1250", "1500", "2000" ];

//start both sections hidden, and then will enable appropriate section on page init
serverSection.style.display="none";
noServerSection.style.display="none";

document.onload = InitPage();

document.getElementById("save").addEventListener("click", SaveSettings);

var qrcode;


function InitPage() {

        
    qrcode = new QRCode(document.getElementById("qrcode"), "https://data.echomav.com");

    cockpit.file(confLocation + "video.conf").read().then((content, tag) => SuccessReadFile(content))
    .catch(error => FailureReadFile(error));

    cockpit.script(scriptLocation + "cockpitScript.sh -z")
    .then(function(content) {
     //   myIP.innerHTML=content.trim();   
     //   myIP2.innerHTML=content.trim();     
    })
    .catch(error => Fail(error));  
    var serverFound = false;

    noServerSection.style.display="none";  //hack until I fix 
    serverSection.style.display="none";  //hack until I fix
    /*
    //get gst-client pipeline_list response
    //the response is JSON, and we are specifically look to make sure the "server" pipeline exists
    cockpit.script(scriptLocation + "cockpitScript.sh -g")
    .then(function(content) {
        try {
              
                break; //skip for now
            var jsonObject = JSON.parse(content);

            for (const pipeline of jsonObject.response.nodes) { 
                if (pipeline.name === "server")
                {     
                    serverFound = true;
                    break;
                }
            }
            if (serverFound)
            {
                //enable the main contents
                mainSection.style.display="block";
                noServerSection.style.display="none";
            }
            else
            {
                //disable the main contents and alert use the video server component is not running
                mainSection.style.display="none";
                noServerSection.style.display="block";   
            }
        }
        catch (error)
        {
              //disable the main contents and alert use the video server component is not running
              mainSection.style.display="none";
              noServerSection.style.display="block";   
        }
    })
    .catch(error => Fail(error));  
    */
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
        
        if(splitResult.length > 0) {
            losHost.value = myConfig.LOS_HOST;
            losPort.value = myConfig.LOS_PORT;
            AddDropDown(losBitrate, losBitrateArray, myConfig.LOS_BITRATE);
            videoHost.value = myConfig.VIDEOSERVER_HOST
           // videoPort.value = myConfig.VIDEOSERVER_PORT;
            videoName.value = myConfig.VIDEOSERVER_STREAMNAME;
            serverURL.innerHTML = "<a href='https://" + videoHost.value + "/LiveApp/play.html?id=" + videoName.value + "' target='_blank'>https://" + videoHost.value + "/LiveApp/play.html?id=" + videoName.value + "</a>";
            qrcode.makeCode("https://" + videoHost.value + "/LiveApp/play.html?id=" + videoName.value);
            AddDropDown(videoBitrate, serverBitrateArray, myConfig.VIDEOSERVER_BITRATE);
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
        Fail(e)
    }
}

function FailureReadFile(error) {
    // Display error message
    output.innerHTML = "Error : " + error.message;

    // Defaults
    videoHost.value = "data.echomav.com";
    //videoPort.value = "1935";    
    videoName.value = "CHANGETOFFAID";
    gimbalPort.value = "7000";
    //platform.value = "NVID";
}

function CheckDisabled(disable){
    if(disable == "Disabled"){
        return 0;
    }
    return disable;
}

function SaveSettings() {

    var serverBitRate = CheckDisabled(videoBitrate.value);  
    var losBitRate = CheckDisabled(losBitrate.value);    
    cockpit.file(confLocation + "video.conf").replace("[Service]\n" + 
        "LOS_HOST=" + losHost.value + "\n" +
        "LOS_PORT=" + losPort.value + "\n" +
        "LOS_BITRATE=" + losBitRate + "\n" +
        "VIDEOSERVER_HOST=" + videoHost.value + "\n" +
        "VIDEOSERVER_PORT=1935" + "\n" +
        "VIDEOSERVER_BITRATE=" + serverBitRate + "\n" +        
        "VIDEOSERVER_STREAMNAME=" + videoName.value + "\n" +
        "PLATFORM=RPIX" + "\n")
        .then(Success)
        .catch(error => Fail(new Error("Failure, settings NOT changed!")));

    //rather than restarting video service, dynamically change settings

    //Handle h264src and los
    console.log("Stopping pipelines...");
    cockpit.spawn(["gst-client", "pipeline_stop", "los"]);
    cockpit.spawn(["gst-client", "pipeline_stop", "h264src"]);

    //change bitrate
    console.log("Changing pipeline h264src bitrate to " + losBitRate + "kbps...");
    var scaledBitrate = losBitRate * 1000;
    var extraText = "controls,repeat_sequence_header=1,h264_profile=1,h264_level=11,video_bitrate=" + scaledBitrate + ",h264_i_frame_period=30,h264_minimum_qp_value=10";
    //extra-controls="controls,repeat_sequence_header=1,h264_profile=1,h264_level=11,video_bitrate=${SCALED_VIDEOSERVER_BITRATE},h264_i_frame_period=30,h264_minimum_qp_value=10
    cockpit.spawn(["gst-client", "element_set", "h264src", "losEncoder", "extra-controls", extraText]);

    //change endpoint
    console.log("Changing pipeline host and port to " + losHost.value + ":" + losPort.value + "...");
    cockpit.spawn(["gst-client", "element_set", "los", "losUDPSink", "host", losHost.value]);
    cockpit.spawn(["gst-client", "element_set", "los", "losUDPSink", "port", losPort.value]);

    if (losBitRate!==0)
    {
        console.log("Starting pipelines...");
        cockpit.spawn(["gst-client", "pipeline_play", "h264src"]);  
        setTimeout(() => {  cockpit.spawn(["gst-client", "pipeline_play", "los"]); }, 1000);        

    }
    //handle server stream
    //stop the pipeline (can't change location without stopping anyway)
    /*
    cockpit.spawn(["gst-client", "pipeline_stop", "server"]);

    //bitrate
    var scaledBitrate = bitRate * 1000;
    //currently using x264enc which does not use scaled bitrate
    cockpit.spawn(["gst-client", "element_set", "server", "serverEncoder", "bitrate", bitRate]);

    //server location
    var serverURI="rtmp://" + videoHost.value + "/LiveApp?streamid=LiveApp/" + videoName.value;
    cockpit.spawn(["gst-client", "element_set", "server", "serverLocation", "location", serverURI]);

    //gimbal receive port (not used for antmedia)
    //cockpit.spawn(["gst-client", "element_set", "h265src", "serverReceivePort", "port", gimbalPort.value]);
*/
    //update the server URL link
    serverURL.innerHTML = "<a href='https://" + videoHost.value + "/LiveApp/play.html?id=" + videoName.value + "' target='_blank'>https://" + videoHost.value + "/LiveApp/play.html?id=" + videoName.value + "</a>";

    //generate the QR Code
    qrcode.makeCode("https://" + videoHost.value + "/LiveApp/play.html?id=" + videoName.value);
    
    //start the pipeline back (unless disabled)
    //if (bitRate!==0)
    //    cockpit.spawn(["gst-client", "pipeline_play", "server"]);    
}

function Success() {
    result.style.color = "green";
    result.innerHTML = "Success, video stream parameters updated...";
    setTimeout(() => result.innerHTML = "", 4000);
}

function Fail(error) {
    result.style.color = "red";
    result.innerHTML = error.message;
}

// Send a 'init' message.  This tells integration tests that we are ready to go
cockpit.transport.wait(function() { });

