'************************************************
'Autoruns.VBS
'Version 1.2.3
'Date: 03-14-2011
'Author: Andre Teixeira - andret@microsoft.com
'************************************************

Option Explicit
Dim objShell
Dim objFSO
Dim XMLOutputFileName, CSVOutputFileName
Dim UID
Dim OutputFormat

Const ForReading = 1, ForWriting = 2
Const OpenFileMode = -2

Main

Sub Main()
    
    On Error Resume Next
    
    wscript.Echo ""
    wscript.Echo "Autoruns Script"
    wscript.Echo "Revision 1.2.3"
    wscript.Echo "2008-2011 Microsoft Corporation"
    wscript.Echo ""
   
    Set objShell = CreateObject("WScript.Shell")
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    If Len(objShell.Environment("PROCESS").Item("PROCESSOR_ARCHITEW6432")) > 0 Then 'Running in WOW, we need to make sure we start the 64 bit version
        wscript.Echo "Script engine is under WOW. Trying to start it in 64 bit mode..."
        If RunScriptin64BitMode Then
            Exit Sub
        Else
            'Script failed to run in 64-bit mode, let's fallback to 32 bit mode.
            DoWork
        End If
    Else
        DoWork
    End If
    wscript.Echo ""
    wscript.Echo "****** Script Finished ******"
End Sub

Function DoWork()
       
    Dim strTXTFile, strXMLFile, strOutputFolder, strArgument, strAutorunscPath, x
    
    On Error Resume Next
    
    strOutputFolder = objFSO.GetAbsolutePathName(".")
    XMLOutputFileName = objFSO.BuildPath(strOutputFolder, objShell.ExpandEnvironmentStrings("%COMPUTERNAME%") + "_Autoruns.XML")
    CSVOutputFileName = objFSO.BuildPath(strOutputFolder, objShell.ExpandEnvironmentStrings("%COMPUTERNAME%") + "_Autoruns.csv")
    
    strAutorunscPath = objFSO.GetAbsolutePathName(objFSO.BuildPath(objFSO.GetParentFolderName(wscript.ScriptFullName), "autorunsc.exe"))
    
    If wscript.Arguments.Count > 0 Then
        Dim bAutorunscPathFound
        bAutorunscPathFound = False
        For x = 0 To (wscript.Arguments.Count - 1)
            strArgument = wscript.Arguments(x)
            If objFSO.FolderExists(strArgument) Then
                If (objFSO.FileExists(objFSO.BuildPath(strArgument, "autorunsc.exe")) And (bAutorunscPathFound = False)) Then
                    strAutorunscPath = objFSO.GetAbsolutePathName(objFSO.BuildPath(strArgument, "autorunsc.exe"))
                    wscript.Echo "AutoRuns Path: '" + strAutorunscPath + "'"
                    bAutorunscPathFound = True
                Else
                    strOutputFolder = objFSO.GetAbsolutePathName(strArgument)
                    XMLOutputFileName = objFSO.BuildPath(strOutputFolder, objShell.ExpandEnvironmentStrings("%COMPUTERNAME%") + "_Autoruns.XML")
                    wscript.Echo "Output path: '" + strOutputFolder + "'"
                End If
            ElseIf (InStr(1, strArgument, "format:", vbTextCompare) > 0) Then
                OutputFormat = LCase(Right(strArgument, Len(strArgument) - InStr(strArgument, ":")))
            Else
                DisplayError "DoWork", 2, "Path does not exist: " + strArgument, "Error accessing ouput folder. Output folder set to local path."
                wscript.Echo "Output path: '" + strOutputFolder + "'"
            End If
        Next
    End If
    
    wscript.Echo "Running Sysinternals AutoRunsC..."
    If RunAutoRunsC(strAutorunscPath, "XML") Then
        wscript.Echo "Editing XML..."
        AddMissingXMLInfo
        If OutputFormat = "html" Then
            wscript.Echo "Editing Creating HTML file..."
            CreateHTMFile strOutputFolder
        End If
    End If
    
    If OutputFormat = "csv" Then
        wscript.Echo "Creating CSV file..."
        CreateCSVFile strAutorunscPath, strOutputFolder
    End If
    
End Function

Function CreateCSVFile(strAutorunscPath, strOutputFolder)
    RunAutoRunsC strAutorunscPath, "csv"
End Function

Function RunAutoRunsC(AutorunscExePath, OutputFormat)
    On Error Resume Next
    Dim intReturn, intEulaAccepted
    Dim strCommandLine, objXMLFile, strStdout
        
    Err.Clear
    intEulaAccepted = 0
    intEulaAccepted = objShell.RegRead("HKCU\Software\Sysinternals\AutoRuns\EulaAccepted")
    If (intEulaAccepted = 0) Then
        wscript.Echo "Creating EULA Key..."
        objShell.RegWrite "HKCU\Software\Sysinternals\AutoRuns\EulaAccepted", 1, "REG_DWORD"
    End If
    
    Err.Clear
    If objFSO.FileExists(AutorunscExePath) Then
        If OutputFormat = "csv" Then
            strCommandLine = objShell.ExpandEnvironmentStrings("%windir%\System32\CMD.EXE") + " /s /c " & Chr(34) & Chr(34) & AutorunscExePath & Chr(34) & " -a -c > " & Chr(34) & CSVOutputFileName & Chr(34) & Chr(34)
        Else
            strCommandLine = objShell.ExpandEnvironmentStrings("%windir%\System32\CMD.EXE") + " /s /c " & Chr(34) & Chr(34) & AutorunscExePath & Chr(34) & " -a -x -v > " & Chr(34) & XMLOutputFileName & Chr(34) & Chr(34)
        End If
        wscript.Echo "Running autorunsc.exe..."
        intReturn = objShell.Run(strCommandLine, 0, True)
        If intReturn <> 0 Then
            RunAutoRunsC = False
            DisplayError "RunAutorunsC", intReturn, "Run AutoRunsSC", "An error ocurred running: " + strCommandLine
        Else
            RunAutoRunsC = True
        End If
    Else
        RunAutoRunsC = False
        DisplayError "RunAutorunsC", 2, "Run AutoRunsSC", "Path not found: " + AutorunscExePath
    End If
    
    If (intEulaAccepted = 0) Then
        'Delete EulaAccepted value since it did not exist before
        objShell.RegDelete "HKCU\Software\Sysinternals\AutoRuns\EulaAccepted"
        wscript.Echo "Removing EULA Key..."
    End If

End Function

Function HexFormat(intNumber)
    HexFormat = Right("00000000" & CStr(Hex(intNumber)), 8)
End Function

Sub AddMissingXMLInfo()
    Dim XMLDoc
    Dim XMLDoc2
    Dim objDataElement, objAutorunsElement
    
    On Error Resume Next
    
    Set XMLDoc = CreateObject("Microsoft.XMLDOM")
    XMLDoc.Load XMLOutputFileName
    If CheckForXMLError(XMLDoc) = 0 Then
        Set objAutorunsElement = XMLDoc.selectNodes("/autoruns").Item(0)
        
        Set XMLDoc2 = CreateObject("Microsoft.XMLDOM")
        XMLDoc2.async = "false"
        XMLDoc2.loadXML "<?xml version=""1.0""?><DiagInfo><MachineName>" & objShell.ExpandEnvironmentStrings("%COMPUTERNAME%") & "</MachineName><TimeField>" & Now & "</TimeField></DiagInfo>"
        Set objDataElement = XMLDoc2.selectNodes("/DiagInfo").Item(0)
        
        objAutorunsElement.appendChild objDataElement
        XMLDoc.Save XMLOutputFileName
    End If
End Sub

Function CheckForXMLError(xmlFile)
    Dim strErrText
        If (Err.Number <> 0) Or (xmlFile.parseError.errorCode <> 0) Then
            If Err.Number <> 0 Then
                DisplayError "Adding PLA Alert.", Err.Number, Err.Source, Err.Description
                CheckForXMLError = Err.Number
            Else
                With xmlFile.parseError
                    strErrText = "Failed to process/ load XML file " & _
                            "due the following error:" & vbCrLf & _
                            "Error #: " & .errorCode & ": " & .reason & _
                            "Line #: " & .Line & vbCrLf & _
                            "Line Position: " & .linepos & vbCrLf & _
                            "Position In File: " & .filepos & vbCrLf & _
                            "Source Text: " & .srcText & vbCrLf & _
                            "Document URL: " & .url
                    CheckForXMLError = .errorCode
                End With
                DisplayError "Processing or loading XML File.", 5000, "BuildingXML", strErrText
            End If
        Else
            CheckForXMLError = 0
        End If
End Function

Function RunScriptin64BitMode()
    On Error Resume Next
    Dim strCmdArguments
    Dim strStdOutFilename
    Dim objStdOutFile
    Dim strArguments, x
    If LCase(objFSO.GetExtensionName(wscript.ScriptFullName)) = "vbs" Then
        strStdOutFilename = objFSO.BuildPath(objFSO.GetSpecialFolder(2), objFSO.GetFileName(wscript.ScriptFullName) & ".log")
        strArguments = ""
        If wscript.Arguments.Count > 0 Then
            For x = 0 To wscript.Arguments.Count - 1
                strArguments = strArguments & " " & Chr(34) & wscript.Arguments(x) & Chr(34) & " "
            Next
        End If
        strCmdArguments = "/c " & objFSO.GetDriveName(wscript.ScriptFullName) & " & cd " & Chr(34) & objFSO.GetParentFolderName(wscript.ScriptFullName) & Chr(34) & " & cscript.exe " & Chr(34) & wscript.ScriptFullName & Chr(34) & strArguments & " > " & Chr(34) & strStdOutFilename & Chr(34)
        ProcessCreate objShell.ExpandEnvironmentStrings("%windir%\System32\CMD.EXE"), strCmdArguments
        If objFSO.FileExists(strStdOutFilename) Then
            Set objStdOutFile = objFSO.OpenTextFile(strStdOutFilename, ForReading, False, OpenFileMode)
            While Not objStdOutFile.AtEndOfStream
                wscript.Echo objStdOutFile.ReadLine
            Wend
            objStdOutFile.Close
            Set objStdOutFile = Nothing
            objFSO.DeleteFile strStdOutFilename, True
            If Err.Number = 0 Then
                RunScriptin64BitMode = True
            End If
        Else
            wscript.Echo "An error ocurred running the command and resulting file was not created:"
            wscript.Echo objShell.ExpandEnvironmentStrings("%windir%\System32\CMD.EXE") & strCmdArguments
            wscript.Echo ""
            wscript.Echo ""
            RunScriptin64BitMode = False
        End If
    Else
        RunScriptin64BitMode = False
    End If
End Function


Sub DisplayError(strErrorLocation, errNumber, errSource, errDescription)
    On Error Resume Next
    wscript.Echo ""
    If errNumber <> 0 Then
        wscript.Echo "Error 0x" & HexFormat(errNumber) & iif(Len(strErrorLocation) > 0, ": " & strErrorLocation, "")
        wscript.Echo errSource & " - " & errDescription
    Else
        wscript.Echo "An error has ocurred!. " & iif(Len(strErrorLocation) > 0, ": " & strErrorLocation, "")
    End If
    wscript.Echo ""
End Sub

Function iif(Expression, Truepart, Falsepart)
    If Expression Then
        iif = Truepart
    Else
        iif = Falsepart
    End If
End Function

Function ShellExec(strCommandLine, ByRef strStdout)
        
    Dim objStdOutFile, strLine, intNumLines, objExec
    
    On Error Resume Next
    Set objExec = objShell.Exec(strCommandLine)
    
    While objExec.Status = 0
        wscript.Sleep 400
    Wend
    
    strStdout = objExec.StdOut.ReadAll
    
    ShellExec = objExec.ExitCode
    
    If Err.Number <> 0 Then
        DisplayError "Running command line '" & strCommandLine & "'", Err.Number, "ShellExec", Err.Description
        ShellExec = Err.Number
    ElseIf (ShellExec <> 0) Then
        DisplayError "Running command line '" & strCommandLine & "'", ShellExec, "ShellExec", objExec.StdErr.ReadAll
    ElseIf strStdout = "" Then
        DisplayError "Running command line '" & strCommandLine & "'", ShellExec, "ShellExec", "Command Did not return any results"
    End If
        
End Function

Sub ProcessCreate(strProcess, strParameters)

    Const SW_HIDE = 0
    Dim strComputer, i, objStartup, objProcess, objWMIService, errResult, objConfig, intProcessID, colProcess, bExit
    strComputer = "."
    i = 0
    
    On Error Resume Next
    
    Set objWMIService = GetObject("winmgmts:" _
                        & "{impersonationLevel=impersonate}!\\" _
                        & strComputer & "\root\cimv2")
                    
    Set objStartup = objWMIService.Get("Win32_ProcessStartup")
    Set objConfig = objStartup.SpawnInstance_
                    objConfig.ShowWindow = SW_HIDE
    
    Set objProcess = objWMIService.Get("Win32_Process")

    If Err.Number <> 0 Then
        DisplayError "Accessing Win32_Process/ Win32_ProcessStartup WMI classes", Err.Number, Err.Source, Err.Description
        Exit Sub
    End If

    errResult = objProcess.Create(strProcess & " " & strParameters, Null, objConfig, intProcessID)
    
    If errResult = 0 Then
        Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
        
        i = 0
        While (Not bExit) And (i < 1000) 'Wait for exit for up 1000 times
            Set colProcess = objWMIService.ExecQuery _
                            ("Select ProcessID From Win32_Process where ProcessID = " & CStr(intProcessID))
            If colProcess.Count = 0 Then
                bExit = True
            Else
                wscript.Sleep 200
                i = i + 1
            End If
        Wend
    Else
        DisplayError "Creating a process using the command line: " & strProcess & " " & strParameters, 5000, "WMI", "Error 0x" & HexFormat(errResult)
    End If

End Sub

Sub CreateHTMFile(strOutputFolderName)
    On Error Resume Next
    Dim strErrText
    Err.Clear
    
    Dim strHTMLFileName, objHTMLFile, xmlStylesheet, xmlStylesheetPath, xmlFile, strXmlFilePath
        
    strXmlFilePath = XMLOutputFileName
        
    strHTMLFileName = objFSO.BuildPath(objFSO.GetAbsolutePathName(strOutputFolderName), objShell.Environment("PROCESS").Item("COMPUTERNAME") & _
                                                    "_Autoruns.htm")
        
    If ExtractEmbeddedXSL(xmlStylesheetPath) Then
    
        Set xmlStylesheet = CreateObject("Microsoft.XMLDOM")
        Set xmlFile = CreateObject("Microsoft.XMLDOM")
        
        xmlFile.Load strXmlFilePath
        
        If CheckForXMLError(xmlFile) = 0 Then
    
            xmlStylesheet.Load xmlStylesheetPath
        
            If CheckForXMLError(xmlStylesheet) <> 0 Then
                objFSO.DeleteFile xmlStylesheetPath, True
                Exit Sub
            End If
        Else
            Exit Sub
        End If
        
        wscript.Echo "Building file: '" & objFSO.GetFileName(strHTMLFileName) & "'"
        Set objHTMLFile = objFSO.OpenTextFile(strHTMLFileName, ForWriting, True, OpenFileMode)
    
        If Err.Number <> 0 Then
            DisplayError "Creating HTML file " & strHTMLFileName, Err.Number, Err.Source, Err.Description
            Exit Sub
        End If
        
        objHTMLFile.Write xmlFile.transformNode(xmlStylesheet)
        
        If Err.Number <> 0 Then
            DisplayError "Error transforming " & strXmlFilePath & " using stylesheet " & xmlStylesheetPath & ".", Err.Number, Err.Source, Err.Description
            objFSO.DeleteFile xmlStylesheetPath, True
            objHTMLFile.Close
            objFSO.DeleteFile strHTMLFileName, True
            Exit Sub
        End If
    
        objHTMLFile.Close
        
        Set xmlFile = Nothing
        Set xmlStylesheet = Nothing
        
        objFSO.DeleteFile xmlStylesheetPath, True
        'objFSO.DeleteFile strXmlFilePath, True
        If Err.Number <> 0 Then
            DisplayError "Error deleting files " & strXmlFilePath & "/ " & xmlStylesheetPath & ".", Err.Number, Err.Source, Err.Description
            Exit Sub
        End If
    End If
End Sub

Function ExtractEmbeddedXSL(ByRef strXSLPath)
    Dim objScriptFile
    Dim objXSL
    Dim bolXSLExtracted, strLine, bCDataBegin
    
    On Error Resume Next
    
    wscript.Echo "Building XSLT File..."
    
    Set objScriptFile = objFSO.OpenTextFile(wscript.ScriptFullName, ForReading, False, OpenFileMode)
    
    If Err.Number <> 0 Then
        DisplayError "Error opening script file to extract XSL file" & wscript.ScriptFullName & ".", Err.Number, Err.Source, Err.Description
        ExtractEmbeddedXSL = False
        Exit Function
    End If
    
    strXSLPath = objFSO.GetSpecialFolder(2) & "\PrintInfoXSL.XSL"
    Set objXSL = objFSO.OpenTextFile(strXSLPath, ForWriting, True, OpenFileMode)
    
    If Err.Number <> 0 Then
        DisplayError "Error creating XSL file " & strXSLPath & ".", Err.Number, Err.Source, Err.Description
        ExtractEmbeddedXSL = False
        Exit Function
    End If
    
    bolXSLExtracted = False
    While (Not objScriptFile.AtEndOfStream) And (Not bolXSLExtracted)
        strLine = objScriptFile.ReadLine
        If strLine = "Sub EmbeddedXSL()" Then
            bCDataBegin = False
            Do
                strLine = objScriptFile.ReadLine
                If Not bCDataBegin Then 'In SDP we cannot have the CDATA notation, therefore we are translating as indicated below
                    If InStr(1, strLine, "<!{CDATA{", vbTextCompare) > 0 Then
                        strLine = Replace(strLine, "<!{CDATA{", "<!" & Chr(91) & "CDATA" & Chr(91), 1, -1, vbTextCompare)
                        bCDataBegin = True
                    End If
                Else
                    If InStr(1, strLine, "}}>", vbTextCompare) > 0 Then
                        strLine = Replace(strLine, "}}>", Chr(93) & Chr(93) & ">", 1, -1, vbTextCompare)
                        bCDataBegin = False
                    End If
                End If
                If Left(strLine, 1) = "'" Then objXSL.WriteLine Right(strLine, Len(strLine) - 1)
            Loop While Left(strLine, 1) = "'"
            bolXSLExtracted = True
        End If
    Wend
    
    If Err.Number <> 0 Then
        DisplayError "Error extracting XSL file from script.", Err.Number, Err.Source, Err.Description
        ExtractEmbeddedXSL = False
    Else
        objXSL.Close
        objScriptFile.Close
        ExtractEmbeddedXSL = True
    End If
    
    Set objXSL = Nothing
    Set objScriptFile = Nothing
    
End Function

Sub EmbeddedXSL()
'<?xml version="1.0"?>
'<!-- 2008 Microsoft Corporation - Andre Teixeira-->
'<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
'<xsl:output method="html"/>
'<xsl:key name="LocationKey" match="item" use="location" />
'
'<xsl:template match="/autoruns">
'<html dir="ltr" xmlns:v="urn:schemas-microsoft-com:vml" gpmc_reportInitialized="false">
'<head>
'<!-- Styles -->
'<style type="text/css">
'  body    { background-color:#FFFFFF; border:1px solid #666666; color:#000000; font-size:68%; font-family:MS Shell Dlg; margin:0,0,10px,0; word-break:normal; word-wrap:break-word; }
'
'  table   { font-size:100%; table-layout:fixed; width:100%; }
'
'  td,th   { overflow:visible; text-align:left; vertical-align:top; white-space:normal; }
'
'  .title  { background:#FFFFFF; border:none; color:#333333; display:block; height:24px; margin:0px,0px,-1px,0px; padding-top:4px; position:relative; table-layout:fixed; width:100%; z-index:5; }
'
'  .he0_expanded    { background-color:#FEF7D6; border:1px solid #BBBBBB; color:#3333CC; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:120%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:0px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%;
'  filter:progid:DXImageTransform.Microsoft.Gradient(GradientType=1,StartColorStr='#FEF7D6',EndColorStr='white');}}
'
'  .he0a   { background-color:#D9E7F2; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:110%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:5px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he0a_expanded { background-color:#D9E7F2; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:110%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:5px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he0b_expanded { background-color:#AAD5D5; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:120%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:5px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he1_expanded    { background-color:#A0BACB; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:10px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he1a_expanded    { background-color:#B3C7D5; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:15px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he1b_expanded    { background-color:#C5DCDE; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:20px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he15_expanded   { background-color:#D9E3EA; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:0px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he4_expanded { background-color:#7EA0B8; border:1px solid #BBBBBB; color:#000000; display:block; font-family:MS Shell Dlg; font-size:100%; height:2.25em; margin-bottom:-1px; font-weight:bold; margin-left:0px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he5_expanded { background-color:#C4C4C4; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:15px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he6_expanded { background-color:#DFDFDF; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:25px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he7_expanded { background-color:#F0F0F0; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:40px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he1    { background-color:#A0BACB; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:10px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he2    { background-color:#E8E8E8; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:30px; margin-right:0px; padding-left:8px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he3    { background-color:#F1F1F1; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:40px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he3noexpand { background-color:#E8E8E8; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:30px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he4    { background-color:#E8E8E8; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:40px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he4h   { background-color:#E8E8E8; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:45px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he4i   { background-color:#F9F9F9; border:1px solid #BBBBBB; color:#000000; display:block; font-family:MS Shell Dlg; font-size:100%; margin-bottom:-1px; margin-left:45px; margin-right:0px; padding-bottom:5px; padding-left:21px; padding-top:4px; position:relative; width:100%; }
'
'  .he4ib  { background-color:#F9F9F9; border:1px solid #BBBBBB; color:#000000; display:block; font-family:MS Shell Dlg; font-size:100%; margin-bottom:-1px; margin-left:10px; margin-right:0px; padding-bottom:5px; padding-left:21px; padding-top:4px; position:relative; width:100%; }
'
'  .he4ic  { background-color:#F9F9F9; border:1px solid #BBBBBB; color:#000000; display:block; font-family:MS Shell Dlg; font-size:100%; margin-bottom:-1px; margin-left:15px; margin-right:0px; padding-bottom:5px; padding-left:21px; padding-top:4px; position:relative; width:100%; }
'
'  .he5    { background-color:#E8E8E8; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; height:2.25em; margin-bottom:-1px; margin-left:50px; margin-right:0px; padding-left:11px; padding-right:5em; padding-top:4px; position:relative; width:100%; }
'
'  .he5h   { background-color:#E8E8E8; border:1px solid #BBBBBB; color:#000000; cursor:hand; display:block; font-family:MS Shell Dlg; font-size:100%; padding-left:11px; padding-right:5em; padding-top:4px; margin-bottom:-1px; margin-left:55px; margin-right:0px; position:relative; width:100%; }
'
'  .he5i   { background-color:#F9F9F9; border:1px solid #BBBBBB; color:#000000; display:block; font-family:MS Shell Dlg; font-size:100%; margin-bottom:-1px; margin-left:55px; margin-right:0px; padding-left:21px; padding-bottom:5px; padding-top: 4px; position:relative; width:100%; }
'
'  DIV .expando { color:#000000; text-decoration:none; display:block; font-family:MS Shell Dlg; font-size:100%; font-weight:normal; position:absolute; right:10px; text-decoration:underline; z-index: 0; }
'
'  .he0 .expando { font-size:100%; }
'
'  .infoFirstCol                     { padding-right:10px; width:20%; }
'  .infoSecondCol                     { padding-right:10px; width:80%; }
'
'  .info, .info0th, .info3, .info4, .disalign  { line-height:1.6em; padding:0px,0px,0px,0px; margin:0px,0px,0px,0px; }
'
'  .disalign TD                      { padding-bottom:5px; padding-right:10px; }
'
'  .info5filename                    { padding-right:10px; width:30%; border-bottom:1px solid #CCCCCC; padding-right:10px;}
'
'  .info0th                          { padding-right:10px; width:12%; border-bottom:1px solid #CCCCCC; padding-right:10px;}
'
'  .info0thsm                        { padding-right:10px; width:5%; border-bottom:1px solid #CCCCCC; padding-right:10px;}
'
'  .info TD                          { padding-right:10px; width:50%; }
'
'  .info3 TD                         { padding-right:10px; width:33%; }
'
'  .info4 TD, .info4 TH              { padding-right:10px; width:25%; }
'
'  .info TH, .info0th, .info0thsm, .info3 TH, .info4 TH, .disalign TH { border-bottom:1px solid #CCCCCC; padding-right:10px; }
'
'  .subtable, .subtable3             { border:1px solid #CCCCCC; margin-left:0px; background:#FFFFFF; margin-bottom:10px; }
'
'  .subtable TD, .subtable3 TD       { padding-left:10px; padding-right:5px; padding-top:3px; padding-bottom:3px; line-height:1.1em; width:10%; }
'
'  .subtable TH, .subtable3 TH       { border-bottom:1px solid #CCCCCC; font-weight:normal; padding-left:10px; line-height:1.6em;  }
'
'  .subtable .footnote               { border-top:1px solid #CCCCCC; }
'
'  .subtable3 .footnote, .subtable .footnote { border-top:1px solid #CCCCCC; }
'
'  .subtable_frame     { background:#D9E3EA; border:1px solid #CCCCCC; margin-bottom:1px; margin-left:10px; }
'
'  .subtable_frame TD  { line-height:1.1em; padding-bottom:3px; padding-left:10px; padding-right:15px; padding-top:3px; }
'
'  .subtable_frame TH  { border-bottom:1px solid #CCCCCC; font-weight:normal; padding-left:10px; line-height:1.6em; }
'
'  .subtableInnerHead { border-bottom:1px solid #CCCCCC; border-top:1px solid #CCCCCC; }
'
'  .explainlink            { color:#000000; text-decoration:none; cursor:hand; }
'
'  .explainlink:hover      { color:#0000FF; text-decoration:underline; }
'
'  .spacer { background:transparent; border:1px solid #BBBBBB; color:#FFFFFF; display:block; font-family:MS Shell Dlg; font-size:100%; height:10px; margin-bottom:-1px; margin-left:43px; margin-right:0px; padding-top: 4px; position:relative; }
'
'  .filler { background:transparent; border:none; color:#FFFFFF; display:block; font:100% MS Shell Dlg; line-height:8px; margin-bottom:-1px; margin-left:43px; margin-right:0px; padding-top:4px; position:relative; }
'
'  .container { display:block; position:relative; }
'
'  .rsopheader { background-color:#A0BACB; border-bottom:1px solid black; color:#333333; font-family:MS Shell Dlg; font-size:130%; font-weight:bold; padding-bottom:5px; text-align:center;
'  filter:progid:DXImageTransform.Microsoft.Gradient(GradientType=0,StartColorStr='#FFFFFF',EndColorStr='#A0BACB')}
'
'  .lines0                           {background-color: #F5F5F5;}
'  .lines1                           {background-color: #F9F9F9;}
'
'  .rsopname { color:#333333; font-family:MS Shell Dlg; font-size:130%; font-weight:bold; padding-left:11px; }
'
'  .gponame{ color:#333333; font-family:MS Shell Dlg; font-size:130%; font-weight:bold; padding-left:11px; }
'
'  .gpotype{ color:#333333; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; padding-left:11px; }
'
'  #uri    { color:#333333; font-family:MS Shell Dlg; font-size:100%; padding-left:11px; }
'
'  #dtstamp{ color:#333333; font-family:MS Shell Dlg; font-size:100%; padding-left:11px; text-align:left; width:30%; }
'
'  #objshowhide { color:#000000; cursor:hand; font-family:MS Shell Dlg; font-size:100%; font-weight:bold; margin-right:0px; padding-right:10px; text-align:right; text-decoration:underline; z-index:2; word-wrap:normal; }
'  #showhideMS { color:#000000; cursor:pointer; font-family:MS Shell Dlg; font-size:100%; margin-right:0px; padding-right:10px; text-align:right; z-index:2; word-wrap:normal;}
'
'  #gposummary { display:block; }
'
'  #gpoinformation { display:block; }
'
'  @media print {
'
'  #objshowhide{ display:none; }
'
'  body    { color:#000000; border:1px solid #000000; }
'
'  .title  { color:#000000; border:1px solid #000000; }
'
'  .he0_expanded    { color:#000000; border:1px solid #000000; }
'
'  .he1_expanded    { color:#000000; border:1px solid #000000; }
'
'  .he1    { color:#000000; border:1px solid #000000; }
'
'  .he2    { color:#000000; background:#EEEEEE; border:1px solid #000000; }
'
'  .he3    { color:#000000; border:1px solid #000000; }
'
'  .he4    { color:#000000; border:1px solid #000000; }
'
'  .he4h   { color:#000000; border:1px solid #000000; }
'
'  .he4i   { color:#000000; border:1px solid #000000; }
'
'  .he5    { color:#000000; border:1px solid #000000; }
'
'  .he5h   { color:#000000; border:1px solid #000000; }
'
'  .he5i   { color:#000000; border:1px solid #000000; }
'
'  }
'
'  v\:* {behavior:url(#default#VML);}
'
'</style>
'<!-- Script 1 -->
'
'<script language="vbscript" type="text/vbscript">
'<!{CDATA{
'<!--
''================================================================================
'' String "strShowHide(0/1)"
'' 0 = Hide all mode.
'' 1 = Show all mode.
'strShowHide = 0
'
''Localized strings
'strShow = "show"
'strHide = "hide"
'strShowAll = "expand all"
'strHideAll = "collapse all"
'strShown = "shown"
'strHidden = "hidden"
'strExpandoNumPixelsFromEdge = "10px"
'
'Function IsSectionHeader(obj)
'    IsSectionHeader = (obj.className = "showHideMS") Or (obj.className = "he0a") Or (obj.className = "he0a_expanded") or (obj.className = "he5_expanded") Or (obj.className = "he6_expanded") Or (obj.className = "he7_expanded") Or (obj.className = "he1_expanded") Or (obj.className = "he1a_expanded") Or (obj.className = "he1b_expanded") Or (obj.className = "he1") Or (obj.className = "he2") Or (obj.className = "he3") Or (obj.className = "he4") Or (obj.className = "he4h") Or (obj.className = "he5") Or (obj.className = "he5h")  or (obj.className = "he4_expanded")
'End Function
'
'
'Function IsSectionExpandedByDefault(objHeader)
'    IsSectionExpandedByDefault = (Right(objHeader.className, Len("_expanded")) = "_expanded")
'End Function
'
'
'' strState must be show | hide | toggle
'Sub SetSectionState(objHeader, strState)
'    ' Get the container object for the section.  It's the first one after the header obj.
'
'    i = objHeader.sourceIndex
'    Set all = objHeader.parentElement.document.all
'    While (all(i).className <> "container")
'        i = i + 1
'    Wend
'
'    Set objContainer = all(i)
'
'    If strState = "toggle" Then
'        If objContainer.style.display = "none" Then
'            SetSectionState objHeader, "show"
'        Else
'            SetSectionState objHeader, "hide"
'        End If
'
'    Else
'        Set objExpando = objHeader.children(1)
'        If strState = "show" Then
'            objContainer.style.display = "block"
'            objExpando.innerHTML = "<v:group class=" & chr(34) & "expando" & chr(34) & " style=" & chr(34) & "width:15px;height:15px;vertical-align:middle" & chr(34) & _
'                                                        " coordsize=" & chr(34) & "100,100" & chr(34) & " title=" & chr(34) & "Collapse" & chr(34) & "><v:oval class=" & chr(34) & "vmlimage" & chr(34) & _
'                                                        " style='width:100;height:100;z-index:0' fillcolor=" & chr(34) & "#B7B7B7" & chr(34) & " strokecolor=" & chr(34) & "#8F8F8F" & chr(34) & "><v:fill type=" & chr(34) & _
'                                                        "gradient" & chr(34) & " angle=" & chr(34) & "0" & chr(34) & " color=" & chr(34) & "#D1D1D1" & chr(34) & " color2=" & chr(34) & "#F5F5F5" & chr(34) & " /></v:oval><v:line class=" & chr(34) & _
'                                                        "vmlimage" & chr(34) & " style=" & chr(34) & "z-index:1" & chr(34) & " from=" & chr(34) & "25,65" & chr(34) & " to=" & chr(34) & "50,37" & chr(34) & " strokecolor=" & chr(34) & "#5D5D5D" & chr(34) & _
'                                                        " strokeweight=" & chr(34) & "2px" & chr(34) & "></v:line><v:line class=" & chr(34) & "vmlimage" & chr(34) & " style=" & chr(34) & "z-index:2" & chr(34) & " from=" & chr(34) & "50,37" & chr(34) & _
'                                                        " to=" & chr(34) & "75,65" & chr(34) & " strokecolor=" & chr(34) & "#5D5D5D" & chr(34) & " strokeweight=" & chr(34) & "2px" & chr(34) & "></v:line></v:group>"
'
'        ElseIf strState = "hide" Then
'            objContainer.style.display = "none"
'            objExpando.innerHTML = "<v:group class=" & chr(34) & "expando" & chr(34) & " style=" & chr(34) & "width:15px;height:15px;vertical-align:middle" & chr(34) & _
'                                                           " coordsize=" & chr(34) & "100,100" & chr(34) & " title=" & chr(34) & "Expand" & chr(34) & "><v:oval class=" & chr(34) & "vmlimage" & chr(34) & _
'                                                           " style='width:100;height:100;z-index:0' fillcolor=" & chr(34) & "#B7B7B7" & chr(34) & " strokecolor=" & chr(34) & "#8F8F8F" & chr(34) & "><v:fill type=" & chr(34) & _
'                                                           "gradient" & chr(34) & " angle=" & chr(34) & "0" & chr(34) & " color=" & chr(34) & "#D1D1D1" & chr(34) & " color2=" & chr(34) & "#F5F5F5" & chr(34) & " /></v:oval><v:line class=" & _
'                                                           chr(34) & "vmlimage" & chr(34) & " style=" & chr(34) & "z-index:1" & chr(34) & " from=" & chr(34) & "25,40" & chr(34) & " to=" & chr(34) & "50,68" & chr(34) & " strokecolor=" & chr(34) & _
'                                                           "#5D5D5D" & chr(34) & " strokeweight=" & chr(34) & "2px" & chr(34) & "></v:line><v:line class=" & chr(34) & "vmlimage" & chr(34) & " style=" & chr(34) & "z-index:2" & chr(34) & " from=" & chr(34) & _
'                                                           "50,68" & chr(34) & " to=" & chr(34) & "75,40" & chr(34) & " strokecolor=" & chr(34) & "#5D5D5D" & chr(34) & " strokeweight=" & chr(34) & "2px" & chr(34) & "></v:line></v:group>"
'        end if
'    End If
'End Sub
'
'
'Sub ShowSection(objHeader)
'    SetSectionState objHeader, "show"
'End Sub
'
'
'Sub HideSection(objHeader)
'    SetSectionState objHeader, "hide"
'End Sub
'
'
'Sub ToggleSection(objHeader)
'    SetSectionState objHeader, "toggle"
'End Sub
'
'
''================================================================================
'' When user clicks anywhere in the document body, determine if user is clicking
'' on a header element.
''================================================================================
'Function document_onclick()
'    Set strsrc    = window.event.srcElement
'
'    While (strsrc.className = "sectionTitle" Or strsrc.className = "expando" Or strsrc.className = "vmlimage" or strsrc.className = "showhideMS")
'        Set strsrc = strsrc.parentElement
'    Wend
'
'    ' Only handle clicks on headers.
'    If Not IsSectionHeader(strsrc) Then Exit Function
'
'    ToggleSection strsrc
'
'    window.event.returnValue = False
'End Function
'
''================================================================================
'' link at the top of the page to collapse/expand all collapsable elements
''================================================================================
'Function objshowhide_onClick()
'    Set objBody = document.body.all
'    Select Case strShowHide
'        Case 0
'            strShowHide = 1
'            objshowhide.innerText = strShowAll
'            For Each obji In objBody
'                If IsSectionHeader(obji) Then
'                    HideSection obji
'                End If
'            Next
'        Case 1
'            strShowHide = 0
'            objshowhide.innerText = strHideAll
'            For Each obji In objBody
'                If IsSectionHeader(obji) Then
'                    ShowSection obji
'                End If
'            Next
'    End Select
'End Function
'
'Function CheckboxMS_Toggle()
'    Set objBody = document.body.all
'    Select Case CheckboxMS.checked
'        Case false
'            For Each obji In objBody
'                If (instr(1, obji.className, "MSSignedtrue") > 0) Then
'                    obji.style.display = "none"
'                End If
'            Next
'            For each obji in objBody
'                If (obji.className = "he1b_expanded") Then
'                        i = obji.sourceIndex
'                        Set objChildren = obji.parentElement.GetElementsByTagName ("*")
'                        HasVisibleItem = false
'                        for each objContainer in objChildren
'                          if (instr(1, objContainer.className, "MSSignedfalse") > 0) then
'                                HasVisibleItem = true
'                          end if
'                        next
'                        if not HasVisibleItem then 
'                          set objToHide = obji.parentElement
'                          objToHide.style.display = "none"
'                        end if
'                End If
'            Next
'        Case true
'            For Each obji In objBody
'                If (instr(1, obji.className, "MSSignedtrue") > 0) Then
'                    obji.style.display = "block"
'                End If
'                If obji.className = "rsopsummary" then
'                  if obji.style.display = "none" then
'                    obji.style.display = "block"
'                  end if
'                end if 
'            Next
'    End Select
'End Function
'
'
''================================================================================
'' onload collapse all except the first two levels of headers (he0, he1)
''================================================================================
'Function window_onload()
'    ' Only initialize once.  The UI may reinsert a report into the webbrowser control,
'    ' firing onLoad multiple times.
'    If UCase(document.documentElement.getAttribute("gpmc_reportInitialized")) <> "TRUE" Then
'
'        ' Set text direction
'        Call fDetDir(UCase(document.dir))
'
'        ' Initialize sections to default expanded/collapsed state.
'        Set objBody = document.body.all
'
'        For Each obji in objBody
'            If IsSectionHeader(obji) Then
'                If IsSectionExpandedByDefault(obji) Then
'                    ShowSection obji
'                Else
'                    HideSection obji
'                End If
'            End If
'        Next
'
'        objshowhide.innerText = strHideAll
'        showhideMS.style.visibility = "visible"
'        CheckboxMS.checked = true
'
'        document.documentElement.setAttribute "gpmc_reportInitialized", "true"
'    End If
'End Function
'
''================================================================================
'' When direction (LTR/RTL) changes, change adjust for readability
''================================================================================
'Function document_onPropertyChange()
'    If window.event.propertyName = "dir" Then
'        Call fDetDir(UCase(document.dir))
'    End If
'End Function
'Function fDetDir(strDir)
'    strDir = UCase(strDir)
'    Select Case strDir
'        Case "LTR"
'            Set colRules = document.styleSheets(0).rules
'            For i = 0 To colRules.length -1
'                Set nug = colRules.item(i)
'                strClass = nug.selectorText
'                If nug.style.textAlign = "right" Then
'                    nug.style.textAlign = "left"
'                End If
'                Select Case strClass
'                    Case "DIV .expando"
'                        nug.style.Left = ""
'                        nug.style.right = strExpandoNumPixelsFromEdge
'                    Case "#objshowhide", "#showhideMS"
'                        nug.style.textAlign = "right"
'                End Select
'            Next
'        Case "RTL"
'            Set colRules = document.styleSheets(0).rules
'            For i = 0 To colRules.length -1
'                Set nug = colRules.item(i)
'                strClass = nug.selectorText
'                If nug.style.textAlign = "left" Then
'                    nug.style.textAlign = "right"
'                End If
'                Select Case strClass
'                    Case "DIV .expando"
'                        nug.style.Left = strExpandoNumPixelsFromEdge
'                        nug.style.right = ""
'                    Case "#objshowhide"
'                        nug.style.textAlign = "left"
'                End Select
'            Next
'    End Select
'End Function
'
''================================================================================
''When printing reports, if a given section is expanded, let's says "shown" (instead of "hide" in the UI).
''================================================================================
'Function window_onbeforeprint()
'    For Each obji In document.all
'        If obji.className = "expando" Then
'            If obji.innerText = strHide Then obji.innerText = strShown
'            If obji.innerText = strShow Then obji.innerText = strHidden
'        End If
'    Next
'End Function
'
''================================================================================
''If a section is collapsed, change to "hidden" in the printout (instead of "show").
''================================================================================
'Function window_onafterprint()
'    For Each obji In document.all
'        If obji.className = "expando" Then
'            If obji.innerText = strShown Then obji.innerText = strHide
'            If obji.innerText = strHidden Then obji.innerText = strShow
'        End If
'    Next
'End Function
'
'Function showhideMS_onClick()
'  CheckboxMS.checked = not (CheckboxMS.checked)
'  CheckboxMS_Toggle()
'End Function
'
'Function CheckboxMS_onClick()
'  CheckboxMS.checked = not (CheckboxMS.checked)
'  CheckboxMS_Toggle()
'End Function
'
''========================================================he3========================
'' Adding keypress support for accessibility
''================================================================================
'Function document_onKeyPress()
'    If window.event.keyCode = "32" Or window.event.keyCode = "13" Or window.event.keyCode = "10" Then 'space bar (32) or carriage return (13) or line feed (10)
'        If window.event.srcElement.className = "expando" Then Call document_onclick() : window.event.returnValue = false
'        If window.event.srcElement.className = "sectionTitle" Then Call document_onclick() : window.event.returnValue = false
'        If window.event.srcElement.id = "objshowhide" Then Call objshowhide_onClick() : window.event.returnValue = false
'    End If
'End Function
'                
'-->
'
'}}>
'</script>
'                
'<!-- Script 2 -->
'
'<script language="javascript"><!{CDATA{
'<!--
'function getExplainWindowTitle()
'{
'        return document.getElementById("explainText_windowTitle").innerHTML;
'}
'
'function getExplainWindowStyles()
'{
'        return document.getElementById("explainText_windowStyles").innerHTML;
'}
'
'function getExplainWindowSettingPathLabel()
'{
'        return document.getElementById("explainText_settingPathLabel").innerHTML;
'}
'
'function getExplainWindowExplainTextLabel()
'{
'        return document.getElementById("explainText_explainTextLabel").innerHTML;
'}
'
'function getExplainWindowPrintButton()
'{
'        return document.getElementById("explainText_printButton").innerHTML;
'}
'
'function getExplainWindowCloseButton()
'{
'        return document.getElementById("explainText_closeButton").innerHTML;
'}
'
'function getNoExplainTextAvailable()
'{
'        return document.getElementById("explainText_noExplainTextAvailable").innerHTML;
'}
'
'function getExplainWindowSupportedLabel()
'{
'        return document.getElementById("explainText_supportedLabel").innerHTML;
'}
'
'function getNoSupportedTextAvailable()
'{
'        return document.getElementById("explainText_noSupportedTextAvailable").innerHTML;
'}
'
'function showExplainText(srcElement)
'{
'    var strSettingName = srcElement.getAttribute("gpmc_settingName");
'    var strSettingPath = srcElement.getAttribute("gpmc_settingPath");
'    var strSettingDescription = srcElement.getAttribute("gpmc_settingDescription");
'
'    if (strSettingDescription == "")
'    {
'                strSettingDescription = getNoExplainTextAvailable();
'    }
'
'    var strSupported = srcElement.getAttribute("gpmc_supported");
'
'    if (strSupported == "")
'    {
'        strSupported = getNoSupportedTextAvailable();
'    }
'
'    var strHtml = "<html>\n";
'    strHtml += "<head>\n";
'    strHtml += "<title>" + getExplainWindowTitle() + "</title>\n";
'    strHtml += "<style type='text/css'>\n" + getExplainWindowStyles() + "</style>\n";
'    strHtml += "</head>\n";
'    strHtml += "<body>\n";
'    strHtml += "<div class='head'>" + strSettingName +"</div>\n";
'    strHtml += "<div class='path'><b>" + getExplainWindowSettingPathLabel() + "</b><br/>" + strSettingPath +"</div>\n";
'    strHtml += "<div class='path'><b>" + getExplainWindowSupportedLabel() + "</b><br/>" + strSupported +"</div>\n";
'    strHtml += "<div class='info'>\n";
'    strHtml += "<div class='hdr'>" + getExplainWindowExplainTextLabel() + "</div>\n";
'    strHtml += "<div class='bdy'>" + strSettingDescription + "</div>\n";
'    strHtml += "<div class='btn'>";
'    strHtml += getExplainWindowPrintButton();
'    strHtml += getExplainWindowCloseButton();
'    strHtml += "</div></body></html>";
'
'    var strDiagArgs = "height=360px, width=630px, status=no, toolbar=no, scrollbars=yes, resizable=yes ";
'    var expWin = window.open("", "expWin", strDiagArgs);
'    expWin.document.write("");
'    expWin.document.close();
'    expWin.document.write(strHtml);
'    expWin.document.close();
'    expWin.focus();
'
'    //cancels navigation for IE.
'    if(navigator.userAgent.indexOf("MSIE") > 0)
'    {
'        window.event.returnValue = false;
'    }
'
'    return false;
'}
'-->
'}}>
'</script>
'
'</head>
'<body>
'
'  <table class="title" cellpadding="0" cellspacing="0">
'	<tr><td colspan="2" class="rsopheader">AutoRuns information</td></tr>
'	<tr><td class="rsopname">Machine name: <xsl:value-of select="DiagInfo/MachineName"/></td>
'    <td id="showhideMS" style="visibility:hidden;cursor:pointer;">
'      <div>
'      Show Signed Microsoft Components<input id="CheckboxMS" type="checkbox" checked="true" ReadOnly="true"/>
'      </div>
'    </td>
'  </tr>
'	<tr><td id="dtstamp">Data collected on: <xsl:value-of select="DiagInfo/TimeField"/></td>
'    <td><div id="objshowhide" tabindex="0" /></td></tr>
'	</table>
'  <div class="filler"></div>
'
'  <div class="container">
'
'<div class="rsopsettings">
'<div class="he0_expanded"><span class="sectionTitle" tabindex="0">Auto Run Information</span>
'  <a class="expando" href="#"></a>
'</div>
'<div class="container">
'  <xsl:for-each select="//item[generate-id(.)=generate-id(key('LocationKey',location))]">
'    <xsl:variable name="CurrentLocation" select="location" />
'    <div class="rsopsummary">
'      <div class="he1b_expanded">
'        <span class="sectionTitle" tabindex="0">
'          <a name="{Bookmark}">
'            <a name="{ProcessorName}">
'              <xsl:value-of select="location"/>
'            </a>
'          </a>
'        </span>
'        <a class="expando" href="#"></a>
'      </div>
'
'      <div class="container">
'        <div class="he4i">
'          <table cellpadding="0" class="info4">
'            <table cellpadding="0" class="infoqfe" >
'              <tr>
'                <th>Name</th>
'                <th>Path</th>
'                <th>Version</th>
'                <th>Company</th>
'                <th>Signer</th>
'              </tr>
'              <xsl:for-each select="//item[location=$CurrentLocation]">
'                <xsl:variable name="SignedByMS" select="(contains (signer, 'Microsoft')) and (contains (signer, '(Verified)'))" />
'                <xsl:variable name="pos" select="position()" />
'                <xsl:variable name="mod" select="($pos mod 2)"/>
'                <tr class="MSSigned{$SignedByMS}" title="{description}">
'                  <td class="lines{$mod}">
'                    <xsl:value-of select="itemname"/>
'                  </td>
'                  <td class="lines{$mod}">
'                    <xsl:value-of select="launchstring"/>
'                  </td>
'                  <td class="lines{$mod}">
'                    <xsl:value-of select="version"/>
'                  </td>
'                  <td class="lines{$mod}">
'                    <xsl:value-of select="company"/>
'                  </td>
'                  <td class="lines{$mod}">
'                    <xsl:value-of select="signer"/>
'                  </td>
'                </tr>
'              </xsl:for-each>
'            </table>
'          </table>
'        </div>
'      </div>
'      <div class="filler"></div>
'    </div>
'	</xsl:for-each>
'</div>
'</div>
'</div>
'</body>
'</html>
'</xsl:template>
'</xsl:stylesheet>
End Sub

'' SIG '' Begin signature block
'' SIG '' MIIazwYJKoZIhvcNAQcCoIIawDCCGrwCAQExCzAJBgUr
'' SIG '' DgMCGgUAMGcGCisGAQQBgjcCAQSgWTBXMDIGCisGAQQB
'' SIG '' gjcCAR4wJAIBAQQQTvApFpkntU2P5azhDxfrqwIBAAIB
'' SIG '' AAIBAAIBAAIBADAhMAkGBSsOAwIaBQAEFD8vAO1sTDYj
'' SIG '' 63/4hfJ/12/1dnRsoIIVejCCBLswggOjoAMCAQICEzMA
'' SIG '' AABa7S/05CCZPzoAAAAAAFowDQYJKoZIhvcNAQEFBQAw
'' SIG '' dzELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
'' SIG '' b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
'' SIG '' Y3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8GA1UEAxMYTWlj
'' SIG '' cm9zb2Z0IFRpbWUtU3RhbXAgUENBMB4XDTE0MDUyMzE3
'' SIG '' MTMxNVoXDTE1MDgyMzE3MTMxNVowgasxCzAJBgNVBAYT
'' SIG '' AlVTMQswCQYDVQQIEwJXQTEQMA4GA1UEBxMHUmVkbW9u
'' SIG '' ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
'' SIG '' MQ0wCwYDVQQLEwRNT1BSMScwJQYDVQQLEx5uQ2lwaGVy
'' SIG '' IERTRSBFU046QjhFQy0zMEE0LTcxNDQxJTAjBgNVBAMT
'' SIG '' HE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggEi
'' SIG '' MA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCzISLf
'' SIG '' atC/+ynJ1Wx6iamNE7yUtel9KWXaf/Qfqwx5YWZUYZYH
'' SIG '' 8NRgSzGbCa99KG3QpXuHX3ah0sYpx5Y6o18XjHbgt5YH
'' SIG '' D8diYbS2qvZGFCkDLiawHUoI4H3TXDASppv2uQ49UxZp
'' SIG '' nbtlJ0LB6DI1Dvcp/95bIEy7L2iEJA+rkcTzzipeWEbt
'' SIG '' qUW0abZUJpESYv1vDuTP+dw/2ilpH0qu7sCCQuuCc+lR
'' SIG '' UxG/3asdb7IKUHgLg+8bCLMbZ2/TBX2hCZ/Cd4igo1jB
'' SIG '' T/9n897sx/Uz3IpFDpZGFCiHHGC39apaQExwtWnARsjU
'' SIG '' 6OLFkN4LZTXUVIDS6Z0gVq/U3825AgMBAAGjggEJMIIB
'' SIG '' BTAdBgNVHQ4EFgQUvmfgLgIbrwpyDTodf4ydayJmEfcw
'' SIG '' HwYDVR0jBBgwFoAUIzT42VJGcArtQPt2+7MrsMM1sw8w
'' SIG '' VAYDVR0fBE0wSzBJoEegRYZDaHR0cDovL2NybC5taWNy
'' SIG '' b3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljcm9z
'' SIG '' b2Z0VGltZVN0YW1wUENBLmNybDBYBggrBgEFBQcBAQRM
'' SIG '' MEowSAYIKwYBBQUHMAKGPGh0dHA6Ly93d3cubWljcm9z
'' SIG '' b2Z0LmNvbS9wa2kvY2VydHMvTWljcm9zb2Z0VGltZVN0
'' SIG '' YW1wUENBLmNydDATBgNVHSUEDDAKBggrBgEFBQcDCDAN
'' SIG '' BgkqhkiG9w0BAQUFAAOCAQEAIFOCkK6mTU5+M0nIs63E
'' SIG '' w34V0BLyDyeKf1u/PlTqQelUAysput1UiLu599nOU+0Q
'' SIG '' Fj3JRnC0ANHyNF2noyIsqiLha6G/Dw2H0B4CG+94tokg
'' SIG '' 0CyrC3Q4LqYQ/9qRqyxAPCYVqqzews9KkwPNa+Kkspka
'' SIG '' XUdE8dyCH+ZItKZpmcEu6Ycj6gjSaeZi33Hx6yO/IWX5
'' SIG '' pFfEky3bFngVqj6i5IX8F77ATxXbqvCouhErrPorNRZu
'' SIG '' W3P+MND7q5Og3s1C2jY/kffgN4zZB607J7v/VCB3xv0R
'' SIG '' 6RrmabIzJ6sFrliPpql/XRIRaAwsozEWDb4hq5zwrhp8
'' SIG '' QNXWgxYV2Cj75TCCBOwwggPUoAMCAQICEzMAAADKbNUy
'' SIG '' EjXE4VUAAQAAAMowDQYJKoZIhvcNAQEFBQAweTELMAkG
'' SIG '' A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAO
'' SIG '' BgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
'' SIG '' dCBDb3Jwb3JhdGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0
'' SIG '' IENvZGUgU2lnbmluZyBQQ0EwHhcNMTQwNDIyMTczOTAw
'' SIG '' WhcNMTUwNzIyMTczOTAwWjCBgzELMAkGA1UEBhMCVVMx
'' SIG '' EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
'' SIG '' ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
'' SIG '' dGlvbjENMAsGA1UECxMETU9QUjEeMBwGA1UEAxMVTWlj
'' SIG '' cm9zb2Z0IENvcnBvcmF0aW9uMIIBIjANBgkqhkiG9w0B
'' SIG '' AQEFAAOCAQ8AMIIBCgKCAQEAlnFd7QZG+oTLnVu3Rsew
'' SIG '' 4bQROQOtsRVzYJzrp7ZuGjw//2XjNPGmpSFeVplsWOSS
'' SIG '' oQpcwtPcUi8MZZogYUBTMZxsjyF9uvn+E1BSYJU6W7lY
'' SIG '' pXRhQamU4K0mTkyhl3BJJ158Z8pPHnGERrwdS7biD8XG
'' SIG '' J8kH5noKpRcAGUxwRTgtgbRQqsVn0fp5vMXMoXKb9CU0
'' SIG '' mPhU3xI5OBIvpGulmn7HYtHcz+09NPi53zUwuux5Mqnh
'' SIG '' qaxVTUx/TFbDEwt28Qf5zEes+4jVUqUeKPo9Lc/PhJiG
'' SIG '' cWURz4XJCUSG4W/nsfysQESlqYsjP4JJndWWWVATWRhz
'' SIG '' /0MMrSvUfzBAZwIDAQABo4IBYDCCAVwwEwYDVR0lBAww
'' SIG '' CgYIKwYBBQUHAwMwHQYDVR0OBBYEFB9e4l1QjVaGvko8
'' SIG '' zwTop4e1y7+DMFEGA1UdEQRKMEikRjBEMQ0wCwYDVQQL
'' SIG '' EwRNT1BSMTMwMQYDVQQFEyozMTU5NStiNDIxOGYxMy02
'' SIG '' ZmNhLTQ5MGYtOWM0Ny0zZmM1NTdkZmM0NDAwHwYDVR0j
'' SIG '' BBgwFoAUyxHoytK0FlgByTcuMxYWuUyaCh8wVgYDVR0f
'' SIG '' BE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQu
'' SIG '' Y29tL3BraS9jcmwvcHJvZHVjdHMvTWljQ29kU2lnUENB
'' SIG '' XzA4LTMxLTIwMTAuY3JsMFoGCCsGAQUFBwEBBE4wTDBK
'' SIG '' BggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQu
'' SIG '' Y29tL3BraS9jZXJ0cy9NaWNDb2RTaWdQQ0FfMDgtMzEt
'' SIG '' MjAxMC5jcnQwDQYJKoZIhvcNAQEFBQADggEBAHdc69eR
'' SIG '' Pc29e4PZhamwQ51zfBfJD+0228e1LBte+1QFOoNxQIEJ
'' SIG '' ordxJl7WfbZsO8mqX10DGCodJ34H6cVlH7XPDbdUxyg4
'' SIG '' Wojne8EZtlYyuuLMy5Pbr24PXUT11LDvG9VOwa8O7yCb
'' SIG '' 8uH+J13oxf9h9hnSKAoind/NcIKeGHLYI8x6LEPu/+rA
'' SIG '' 4OYdqp6XMwBSbwe404hs3qQGNafCU4ZlEXcJjzVZudiG
'' SIG '' qAD++DF9LPSMBZ3AwdV3cmzpTVkmg/HCsohXkzUAfFAr
'' SIG '' vFn8/hwpOILT3lKXRSkYTpZbnbpfG6PxJ1DqB5XobTQN
'' SIG '' OFfcNyg1lTo4nNTtaoVdDiIRXnswggW8MIIDpKADAgEC
'' SIG '' AgphMyYaAAAAAAAxMA0GCSqGSIb3DQEBBQUAMF8xEzAR
'' SIG '' BgoJkiaJk/IsZAEZFgNjb20xGTAXBgoJkiaJk/IsZAEZ
'' SIG '' FgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBS
'' SIG '' b290IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0xMDA4
'' SIG '' MzEyMjE5MzJaFw0yMDA4MzEyMjI5MzJaMHkxCzAJBgNV
'' SIG '' BAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
'' SIG '' VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQg
'' SIG '' Q29ycG9yYXRpb24xIzAhBgNVBAMTGk1pY3Jvc29mdCBD
'' SIG '' b2RlIFNpZ25pbmcgUENBMIIBIjANBgkqhkiG9w0BAQEF
'' SIG '' AAOCAQ8AMIIBCgKCAQEAsnJZXBkwZL8dmmAgIEKZdlNs
'' SIG '' PhvWb8zL8epr/pcWEODfOnSDGrcvoDLs/97CQk4j1XIA
'' SIG '' 2zVXConKriBJ9PBorE1LjaW9eUtxm0cH2v0l3511iM+q
'' SIG '' c0R/14Hb873yNqTJXEXcr6094CholxqnpXJzVvEXlOT9
'' SIG '' NZRyoNZ2Xx53RYOFOBbQc1sFumdSjaWyaS/aGQv+knQp
'' SIG '' 4nYvVN0UMFn40o1i/cvJX0YxULknE+RAMM9yKRAoIsc3
'' SIG '' Tj2gMj2QzaE4BoVcTlaCKCoFMrdL109j59ItYvFFPees
'' SIG '' CAD2RqGe0VuMJlPoeqpK8kbPNzw4nrR3XKUXno3LEY9W
'' SIG '' PMGsCV8D0wIDAQABo4IBXjCCAVowDwYDVR0TAQH/BAUw
'' SIG '' AwEB/zAdBgNVHQ4EFgQUyxHoytK0FlgByTcuMxYWuUya
'' SIG '' Ch8wCwYDVR0PBAQDAgGGMBIGCSsGAQQBgjcVAQQFAgMB
'' SIG '' AAEwIwYJKwYBBAGCNxUCBBYEFP3RMU7TJoqV4ZhgO6gx
'' SIG '' b6Y8vNgtMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBB
'' SIG '' MB8GA1UdIwQYMBaAFA6sgmBAVieX5SUT/CrhClOVWeSk
'' SIG '' MFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwubWlj
'' SIG '' cm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL21pY3Jv
'' SIG '' c29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYw
'' SIG '' RAYIKwYBBQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0
'' SIG '' LmNvbS9wa2kvY2VydHMvTWljcm9zb2Z0Um9vdENlcnQu
'' SIG '' Y3J0MA0GCSqGSIb3DQEBBQUAA4ICAQBZOT5/Jkav629A
'' SIG '' sTK1ausOL26oSffrX3XtTDst10OtC/7L6S0xoyPMfFCY
'' SIG '' gCFdrD0vTLqiqFac43C7uLT4ebVJcvc+6kF/yuEMF2nL
'' SIG '' pZwgLfoLUMRWzS3jStK8cOeoDaIDpVbguIpLV/KVQpzx
'' SIG '' 8+/u44YfNDy4VprwUyOFKqSCHJPilAcd8uJO+IyhyugT
'' SIG '' pZFOyBvSj3KVKnFtmxr4HPBT1mfMIv9cHc2ijL0nsnlj
'' SIG '' VkSiUc356aNYVt2bAkVEL1/02q7UgjJu/KSVE+Traeep
'' SIG '' oiy+yCsQDmWOmdv1ovoSJgllOJTxeh9Ku9HhVujQeJYY
'' SIG '' XMk1Fl/dkx1Jji2+rTREHO4QFRoAXd01WyHOmMcJ7oUO
'' SIG '' jE9tDhNOPXwpSJxy0fNsysHscKNXkld9lI2gG0gDWvfP
'' SIG '' o2cKdKU27S0vF8jmcjcS9G+xPGeC+VKyjTMWZR4Oit0Q
'' SIG '' 3mT0b85G1NMX6XnEBLTT+yzfH4qerAr7EydAreT54al/
'' SIG '' RrsHYEdlYEBOsELsTu2zdnnYCjQJbRyAMR/iDlTd5aH7
'' SIG '' 5UcQrWSY/1AWLny/BSF64pVBJ2nDk4+VyY3YmyGuDVyc
'' SIG '' 8KKuhmiDDGotu3ZrAB2WrfIWe/YWgyS5iM9qqEcxL5rc
'' SIG '' 43E91wB+YkfRzojJuBj6DnKNwaM9rwJAav9pm5biEKgQ
'' SIG '' tDdQCNbDPTCCBgcwggPvoAMCAQICCmEWaDQAAAAAABww
'' SIG '' DQYJKoZIhvcNAQEFBQAwXzETMBEGCgmSJomT8ixkARkW
'' SIG '' A2NvbTEZMBcGCgmSJomT8ixkARkWCW1pY3Jvc29mdDEt
'' SIG '' MCsGA1UEAxMkTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNh
'' SIG '' dGUgQXV0aG9yaXR5MB4XDTA3MDQwMzEyNTMwOVoXDTIx
'' SIG '' MDQwMzEzMDMwOVowdzELMAkGA1UEBhMCVVMxEzARBgNV
'' SIG '' BAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
'' SIG '' HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEh
'' SIG '' MB8GA1UEAxMYTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
'' SIG '' MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA
'' SIG '' n6Fssd/bSJIqfGsuGeG94uPFmVEjUK3O3RhOJA/u0afR
'' SIG '' TK10MCAR6wfVVJUVSZQbQpKumFwwJtoAa+h7veyJBw/3
'' SIG '' DgSY8InMH8szJIed8vRnHCz8e+eIHernTqOhwSNTyo36
'' SIG '' Rc8J0F6v0LBCBKL5pmyTZ9co3EZTsIbQ5ShGLieshk9V
'' SIG '' UgzkAyz7apCQMG6H81kwnfp+1pez6CGXfvjSE/MIt1Nt
'' SIG '' UrRFkJ9IAEpHZhEnKWaol+TTBoFKovmEpxFHFAmCn4Tt
'' SIG '' VXj+AZodUAiFABAwRu233iNGu8QtVJ+vHnhBMXfMm987
'' SIG '' g5OhYQK1HQ2x/PebsgHOIktU//kFw8IgCwIDAQABo4IB
'' SIG '' qzCCAacwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU
'' SIG '' IzT42VJGcArtQPt2+7MrsMM1sw8wCwYDVR0PBAQDAgGG
'' SIG '' MBAGCSsGAQQBgjcVAQQDAgEAMIGYBgNVHSMEgZAwgY2A
'' SIG '' FA6sgmBAVieX5SUT/CrhClOVWeSkoWOkYTBfMRMwEQYK
'' SIG '' CZImiZPyLGQBGRYDY29tMRkwFwYKCZImiZPyLGQBGRYJ
'' SIG '' bWljcm9zb2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9v
'' SIG '' dCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHmCEHmtFqFKoKWt
'' SIG '' THNY9AcTLmUwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDov
'' SIG '' L2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVj
'' SIG '' dHMvbWljcm9zb2Z0cm9vdGNlcnQuY3JsMFQGCCsGAQUF
'' SIG '' BwEBBEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3d3dy5t
'' SIG '' aWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNyb3NvZnRS
'' SIG '' b290Q2VydC5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgw
'' SIG '' DQYJKoZIhvcNAQEFBQADggIBABCXisNcA0Q23em0rXfb
'' SIG '' znlRTQGxLnRxW20ME6vOvnuPuC7UEqKMbWK4VwLLTiAT
'' SIG '' UJndekDiV7uvWJoc4R0Bhqy7ePKL0Ow7Ae7ivo8KBciN
'' SIG '' SOLwUxXdT6uS5OeNatWAweaU8gYvhQPpkSokInD79vzk
'' SIG '' eJkuDfcH4nC8GE6djmsKcpW4oTmcZy3FUQ7qYlw/FpiL
'' SIG '' ID/iBxoy+cwxSnYxPStyC8jqcD3/hQoT38IKYY7w17gX
'' SIG '' 606Lf8U1K16jv+u8fQtCe9RTciHuMMq7eGVcWwEXChQO
'' SIG '' 0toUmPU8uWZYsy0v5/mFhsxRVuidcJRsrDlM1PZ5v6oY
'' SIG '' emIp76KbKTQGdxpiyT0ebR+C8AvHLLvPQ7Pl+ex9teOk
'' SIG '' qHQ1uE7FcSMSJnYLPFKMcVpGQxS8s7OwTWfIn0L/gHkh
'' SIG '' gJ4VMGboQhJeGsieIiHQQ+kr6bv0SMws1NgygEwmKkgk
'' SIG '' X1rqVu+m3pmdyjpvvYEndAYR7nYhv5uCwSdUtrFqPYmh
'' SIG '' dmG0bqETpr+qR/ASb/2KMmyy/t9RyIwjyWa9nR2HEmQC
'' SIG '' PS2vWY+45CHltbDKY7R4VAXUQS5QrJSwpXirs6CWdRrZ
'' SIG '' kocTdSIvMqgIbqBbjCW/oO+EyiHW6x5PyZruSeD3AWVv
'' SIG '' iQt9yGnI5m7qp5fOMSn/DsVbXNhNG6HY+i+ePy5VFmvJ
'' SIG '' E6P9MYIEwTCCBL0CAQEwgZAweTELMAkGA1UEBhMCVVMx
'' SIG '' EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
'' SIG '' ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
'' SIG '' dGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0IENvZGUgU2ln
'' SIG '' bmluZyBQQ0ECEzMAAADKbNUyEjXE4VUAAQAAAMowCQYF
'' SIG '' Kw4DAhoFAKCB2jAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
'' SIG '' NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIB
'' SIG '' FTAjBgkqhkiG9w0BCQQxFgQU2yVPnPIzSgcQoyd6pA4f
'' SIG '' WFuFsEcwegYKKwYBBAGCNwIBDDFsMGqgUIBOAEMAVABT
'' SIG '' AF8ATgBlAHQAdwBvAHIAawBpAG4AZwBfAE0AYQBpAG4A
'' SIG '' XwBnAGwAbwBiAGEAbABfAEEAdQB0AG8AcgB1AG4AcwAu
'' SIG '' AHYAYgBzoRaAFGh0dHA6Ly9taWNyb3NvZnQuY29tMA0G
'' SIG '' CSqGSIb3DQEBAQUABIIBAEROUmQ74zDJtbtYkXx9cfpN
'' SIG '' txQGY1mPfUMPSU6DJrLF2CS4DSQI3NlzbuOFdqauilmh
'' SIG '' x4fn79DQXNVs4Ic+z3qREe18Uox8aakqOzxXzRwPYiNh
'' SIG '' qvPlBbqM8S5xrJKaykN2H8VY6ESegVMICrYSKKsuI9W8
'' SIG '' pSie/VjrVxnGkYuk/cq81gqCSkTHo7yidANE8y14J/sX
'' SIG '' X6owx8GlqTJ6husPTcvRPQr2D4u97ip2Bfir9PgsVEN/
'' SIG '' mye70O+DUwQF8GYmInyGcujq/Rg/0/JiFAb3sS3Z+Llp
'' SIG '' LGkbs/hkbefp9xUFwdujR55rklwgBIsetphDZJwGRuLn
'' SIG '' m2JP7fYjHqehggIoMIICJAYJKoZIhvcNAQkGMYICFTCC
'' SIG '' AhECAQEwgY4wdzELMAkGA1UEBhMCVVMxEzARBgNVBAgT
'' SIG '' Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
'' SIG '' BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEhMB8G
'' SIG '' A1UEAxMYTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBAhMz
'' SIG '' AAAAWu0v9OQgmT86AAAAAABaMAkGBSsOAwIaBQCgXTAY
'' SIG '' BgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3
'' SIG '' DQEJBTEPFw0xNDEwMjAxODA4MjlaMCMGCSqGSIb3DQEJ
'' SIG '' BDEWBBSIQR+3qoiDgVebXqHSaWRriLCknDANBgkqhkiG
'' SIG '' 9w0BAQUFAASCAQCG5l2G09PXI8FzKeysg8X/cSOOxMGy
'' SIG '' nRHfGLEdIvkOR1BgX7rgfnAwxj+JD+vwOoQQ0pcr/BnO
'' SIG '' o4Nse9aYEu93jSRaOijtADVXVh4vP8hIqw7SitbxK3KH
'' SIG '' hSARufA3QQp6Vd6kcdT968YP6x9ljiLu3i0QF9mYkY7c
'' SIG '' IfIzqwVPq82IFzGhUCnoDj7+kNhbszHwY0x5/PvJfW2W
'' SIG '' uMgcV+5FW6cK9/b3v0vM9CDAt1z8VzgFVfnPwenvf7ac
'' SIG '' v5DVHi/hhkbqN6agOYU0Oa/eNgn8Qzb6TQGXexjH1r3A
'' SIG '' 1nJ7OHhB/dRMP+Sqbhntx/WtBFDBZU+/N09GkdBEgMxA
'' SIG '' Mkey
'' SIG '' End signature block
