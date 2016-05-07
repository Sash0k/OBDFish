/*
 * Copyright (C) 2016 Jens Drescher, Germany
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


import QtQuick 2.0
import Sailfish.Silica 1.0
import "pages"
import org.nemomobile.notifications 1.0
import bluetoothconnection 1.0
import bluetoothdata 1.0
import filewriter 1.0
import QtSensors 5.0 as Sensors
import "tools"

ApplicationWindow
{
    //Define global variables
    property bool bConnected: false;
    property bool bConnecting: false;
    property bool bCommandRunning: false;
    property string sReceiveBuffer: "";
    property string sDebugFileBuffer: "";
    property string sELMVersion: "";
    property string sSupportedPIDs0100: "";

    //Init C++ classes, libraries
    BluetoothConnection{ id: id_BluetoothConnection }
    BluetoothData{ id: id_BluetoothData }
    FileWriter{ id: id_FileWriter }
    Notification { id: mainPageNotification }

    Connections
    {
        target: id_BluetoothData
        onSigReadDataReady:     //This is called from C++ if there is data via bluetooth
        {
            //Check received data
            sDebugFileBuffer = sDebugFileBuffer + sData;
            fncGetData(sData);
        }
    }

    //Define global functions
    function fncViewMessage(sCategory, sMessage)
    {
        mainPageNotification.category = (sCategory === "error")
            ? "x-sailfish.sailfish-utilities.error"
            : "x-sailfish.sailfish-utilities.info";
        mainPageNotification.previewBody = "MythOBD";
        mainPageNotification.previewSummary = sMessage;
        mainPageNotification.close();
        mainPageNotification.publish();
    }

    //This function accepts an AT command to be send to the ELM
    function fncStartCommand(sCommand)
    {
        //Don't do anything if there is already an active command.
        if (bCommandRunning) return;

        //Set active command bit
        bCommandRunning = true;

        //Cleare receive buffer
        sReceiveBuffer = "";

        //Send the AT command via bluetooth
        id_BluetoothData.sendHex(sCommand);
    }

    //Data which is received via bluetooth is passed into this function
    function fncGetData(sData)
    {
        //WARNING: Don't trim here. ELM might send leading/trailing spaces/carriage returns.
        //They might get lost but are needed!!!

        //Fill in new data into buffer
        sReceiveBuffer = sReceiveBuffer + sData;

        console.log("fncGetData, sReceiveBuffer: " + sReceiveBuffer);

        //If the ELM is ready with sending a command, it always sends the same end characters.
        //These are three characters: two carriage returns (\r) followed by >
        //Check if the end characters are already in the buffer.
        if (sReceiveBuffer.search(/\r>/g) !== -1 || sReceiveBuffer.search(/\n>/g) !== -1)
        {
            //The ELM has completely answered the command.
            //Received data is now in sReceiveBuffer.

            //Cut off the end characters
            if (sReceiveBuffer.search(/\r>/g) !== -1)
                sReceiveBuffer = sReceiveBuffer.substring(0, sReceiveBuffer.search(/\r>/g));
            else if (sReceiveBuffer.search(/\n>/g) !== -1)
                sReceiveBuffer = sReceiveBuffer.substring(0, sReceiveBuffer.search(/\n>/g));

            sReceiveBuffer = sReceiveBuffer.trim();

            //Set ready bit
            bCommandRunning = false;
        }
    }

    function fncShowMessage(sMessage, iTime)
    {
        messagebox.showMessage(sMessage, iTime);
    }

    Sensors.OrientationSensor
    {
        id: rotationSensor
        active: true
        property int angle: reading.orientation ? _getOrientation(reading.orientation) : 0
        function _getOrientation(value)
        {
            switch (value)
            {
                case 2:
                    return 180
                case 3:
                    return -90
                case 4:
                    return 90
                default:
                    return 0
            }
        }
    }

    Messagebox
    {
        id: messagebox
        rotation: rotationSensor.angle
        width: Math.abs(rotationSensor.angle) == 90 ? parent.height : parent.width
        Behavior on rotation { SmoothedAnimation { duration: 500 } }
        Behavior on width { SmoothedAnimation { duration: 500 } }
    }

    initialPage: Component { MainPage { } }
    cover: Qt.resolvedUrl("cover/CoverPage.qml")
    allowedOrientations: Orientation.All
    _defaultPageOrientations: Orientation.All
}


