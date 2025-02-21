#!/usr/bin/env python3

import json
import sys
import os
import inspect
import argparse
from enum import Enum

class OutputType( Enum ):
  STANDARD   = "STANDARD"
  GITHUB     = "GITHUB"

  def __str__( self ) :
    return self.value


def dumpFile( filename, errorLabel, success=False, bannerMsg="", banner="!" * 80 ) :
  print( "\nOpening logfile {0}".format( filename ) )
  print( "{msg}\n{banner}".format( msg=bannerMsg, banner=banner ) )
  with open( filename, 'r') as f:
    current = next( f, None )
    last    = None
    for line in f.readlines() :
      print( current, end="" )
      current = line
    # last line
    if current is not None and not success :
      print( errorLabel.format( title=filename, message=current )  )
    else :
      print( current )
      
  print( banner )
  print( "\nClosing logfile {0}".format( filename ) )

def getLogsPrintedStr( masterDict, masterLog ) :
  indent = "  "
  outputFormat = "{desc:=<32}=> {file}\n"

  output = outputFormat.format( desc="master log [developers only]", file=masterLog )
  for test, testlog in masterDict.items() :
    if not testlog["success"] :
      output += outputFormat.format( desc=indent * 1 + "{0} stdout ".format( test ), file=testlog["stdout"] )
      for step, steplog in testlog["steps"].items() :
        if not steplog["success"] :
          output += outputFormat.format( desc=indent * 2 + "{0} stdout ".format( step ), file=steplog["logfile"] )

  return output

def getSummaryPrintedStr( masterDict, metadata ) :
  indent = "  "
  outputHeadFormat = " TESTSUITE {name:<24} : {status:<24}   \n"
  outputTblFormat = "| {name:<24} | {status:<24} | {reason:<40} | \n"
  cmdFormat    = "{runner} {file} -t {test} {offset} -s LOCAL"
  output = "SUMMARY OF TEST FAILURES\n" 
  #output += outputFormat.format( name="NAME", status="STATUS", reason="REASON" )
  for test, testlog in masterDict.items() :
    output += "\n ----- \n "
    #if not testlog["success"] :
    testCmd = cmdFormat.format(
                                runner=metadata["rel_exec"],
                                file=metadata["rel_prefix"] + "/" + metadata["rel_file"],
                                test=test,
                                offset="" if metadata["rel_offset"] == "" else "-d " + metadata["rel_offset"]
                                )
    if testlog["success"]:
      status_emoji = "PASSED :white_check_mark:"
      reason = " "
    else:
      status_emoji = "FAILED :red_circle:"
      reason = testlog[ "line" ]
    output += outputHeadFormat.format( name=test, status=status_emoji)
    output += outputTblFormat.format( name="STEP", status="STATUS", reason="REASON" )
    output += outputTblFormat.format( name="--------", status="--------", reason="--------" )
    for step, steplog in testlog["steps"].items() :
      #if not steplog["success"] :
      if steplog["success"]:
        status_emoji = ":white_check_mark:"
        reason = " "
      else:
        status_emoji = ":red_circle:"
        reason = steplog[ "line" ]
      output += outputTblFormat.format( name=step, status=status_emoji, reason=reason )
      #output += outputFormat.format( name=indent * 1 + step, reason=steplog[ "line" ] )
    output += "\n\n\n [TO REPRODUCE LOCALLY] : " + testCmd + "\n\n"
  return output



def getOptionsParser():
  parser = argparse.ArgumentParser( 
                                    description="Outputs summary and logs for failed tests",
                                  )

  parser.add_argument( 
                      "masterLog",
                      help="Master logfile output from runner.py",
                      type=str,
                      default=""
                      )
  # parser.add_argument( 
  #                     "-t", "--tests",
  #                     help="Test names matching respective JSON test name to run",
  #                     dest="tests",
  #                     type=str,
  #                     nargs="+",
  #                     default=[]
  #                     )
  parser.add_argument( 
                      "-o", "--outputType",
                      dest="outputType",
                      help="Set the output type style for enhanced readability",
                      type=OutputType,
                      choices=list( OutputType ),
                      default=OutputType.STANDARD
                      )
  parser.add_argument( 
                      "-e", "--exec",
                      dest="exec",
                      help="Exec to use when outputting instructions on reproduction",
                      type=str,
                      default="<location to hpc-workflows/.ci/runner.py>"
                      )
  parser.add_argument( 
                      "-p", "--prefix",
                      dest="prefix",
                      help="Prefix path to prepend to test config when outputting instructions on reproduction",
                      type=str,
                      default="<folder path to test config>"
                      )
  parser.add_argument( 
                      "-f", "--failedStepsOnly",
                      dest="failedStepsOnly",
                      help="Only output the failed steps instead of the whole test",
                      default=False,
                      const=True,
                      action='store_const'
                      )
  parser.add_argument( 
                      "-m", "--markStepsOnly",
                      dest="markStepsOnly",
                      help="Only mark failur in the failed steps",
                      default=False,
                      const=True,
                      action='store_const'
                      )
  parser.add_argument( 
                      "-s", "--summaryOnly",
                      dest="summaryOnly",
                      help="Only output the summary and no logs",
                      default=False,
                      const=True,
                      action='store_const'
                      )
  parser.add_argument(
                      "-n", "--noExitCode",
                      dest="noExitCode",
                      help="Always exit normally without exit code reflecting success",
                      default=False,
                      const=True,
                      action='store_const'
                      )
  return parser

class Options(object):
  """Empty namespace"""
  pass

def main() :
  parser  = getOptionsParser()
  options = Options()
  parser.parse_args( namespace=options )

  fp = open( options.masterLog )
  logs = json.load( fp )

  metadata = logs.pop( "metadata", None )
  metadata["rel_exec"]   = options.exec 
  metadata["rel_prefix"] = options.prefix 
  failure = False

  startGroup  = None
  stopGroup   = None
  noticeLabel = None
  errorLabel  = None

  testErrorLabel  = None

  if options.outputType == OutputType.STANDARD :
    startGroup  = ""
    stopGroup   = ""
    noticeLabel = ""
    errorLabel  = "{{message}}"
  elif options.outputType == OutputType.GITHUB :
    startGroup  = "::group::{title}"
    stopGroup   = "::endgroup::"
    noticeLabel = "::notice title={title}::{message}"
    errorLabel  = "::error title={title}::{{message}}"
  
  if options.markStepsOnly :
    testErrorLabel = "{{message}}"
  else :
    testErrorLabel = errorLabel
  

  if not options.summaryOnly :
    print( "Finding tests that failed..." )
    for test, testlog in logs.items() :
      if not testlog["success"] :
        failure = True
        testTitle = "STDOUT FOR TEST {test}".format( test=test )
        print( startGroup.format( title=testTitle ) )
        print( "\n".join([( "#" * 80 )]*3 ) )
        print( "Test {test} failed, printing stdout".format( test=test ) )
        dumpFile( testlog["stdout"], testErrorLabel.format( title=test ), bannerMsg=testTitle, banner="\n".join([( "!#!#" * 20 )]*2 ) )

        print( "Finding logs for steps that failed..." )
        print( stopGroup )

        longestStep = len( max( testlog["steps"].keys(), key=len ) ) + len( test ) + 1

        for step, steplog in testlog["steps"].items() :
          stepAncestry = "{test}.{step}".format( test=test, step=step )
          stepTitle = "  > STDOUT FOR STEP {step}".format( step=stepAncestry )
          if not options.failedStepsOnly or not steplog["success"] :
            # print( noticeLabel.format( title=stepAncestry, message=stepTitle ) )
            if not steplog["success"] :
              print( startGroup.format( title="{0:<{1}}".format( stepTitle, longestStep + 20 ) + " <- CLICK HERER !!! ERROR !!!" ) )
              print( "Step {step} failed, printing stdout".format( step=stepAncestry ) )
            else :
              print( startGroup.format( title=stepTitle ) )

            dumpFile( steplog["logfile"], errorLabel.format( title=stepAncestry ), steplog["success"], bannerMsg=stepTitle )
            print( stopGroup )

        

    print( "\n", flush=True, end="" )

    print( startGroup.format( title="Summary" ) )
  
    hereThereBeLogs = "^^ !!! ALL LOG FILES ARE PRINTED TO SCREEN ABOVE FOR REFERENCE !!! ^^"
    refLogs  = getLogsPrintedStr( logs, os.path.abspath( options.masterLog ) )
    howToUse = ""

    if options.outputType == OutputType.STANDARD :
      howToUse = inspect.cleandoc(
                  hereThereBeLogs +
                """
                      To find when a logfile is printed search for (remove single quotes) :
                      'Opening logfile <logfile>'
                      OR
                      'Closing logfile <logfile>'
                      Replacing <logfile> with the logfile you wish to see
                """ )
    elif options.outputType == OutputType.GITHUB :
      howToUse = inspect.cleandoc(
                  hereThereBeLogs +
                """
                      To find when a logfile is printed use the above sections to view the output.
                      They are labeled as TEST|STEP then <test> or <test>.<step>, respectively.
                      Click on the above section to expand or collapse it.

                      Sections with the errors summarized below are labelled above.

                      If logs are too long and/or truncated, please download the logfiles via the artifacts
                      found via the summary page if available, otherwise download normally
                """ )

    print( "~ How to use brief ~\n{help}\n\nOr refer to log files : \n{reflogs}\n{addendum}\n".format(
                                                                                                    help=howToUse,
                                                                                                    reflogs=refLogs,
                                                                                                    addendum=hereThereBeLogs
                                                                                                    ),
      flush=True )

  if options.summaryOnly :
    print( startGroup.format( title="Summary" ) )
    
  # Now do executive summary
  print( getSummaryPrintedStr( logs, metadata ) )

  note = inspect.cleandoc(
                          """
                              Note: HPC users should use '-s LOCAL' in reproduce command with caution
                                    as it will run directly where you are, consider using an interactive node
                          """
                          )
  print( note )
  # Force wait for stdout to be finished
  try:
    os.fsync( sys.stdout.fileno() )
  except:
    pass


  if failure :
    print( "FAILURE!" )
    if not options.noExitCode :
      # Exit with bad status so people know where to look since that might be 
      # an issue as this will look "successful"
      exit( 1 )

if __name__ == '__main__' :
  main()
