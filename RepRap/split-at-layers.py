#!/bin/python
# Simple command line python program intended to split a Skeinforge
# generated GCODE file into multiple parts based on a list of z-depths.
# The Skeinforge file must be generated with all of the comments left
# in the file.
#
# This has only been tested with the output from Skienforge 41
#
# This code is licensed under GPL Version 2 or later, your choice.
#

import sys
import os

if( len(sys.argv) < 2 ) :
    print "Command Line Usage: split-at-layers file_to_split z_height [ z_height ]*"
    sys.exit()
    
with open( sys.argv[1], "r" ) as sourceFile :
    layers = []
    for arg in sys.argv[2:] :
        layers.append( float(arg) )
    pathparts = os.path.splitext(sys.argv[1])
    outputFileCount = 1
    outputFile = open( pathparts[0] + "_part_" + str(outputFileCount) + pathparts[1], "w" )
    for line in sourceFile :
        words = line.rsplit(" ")
        if( len(words) == 3 and words[0] == "(<layer>" and words[2] == ")\n" ) :
            if( float( words[1] ) in layers ) :
                print "found layer " + str( layers[ outputFileCount - 1 ] )
                outputFile.close()
                outputFileCount = outputFileCount + 1
                outputFile = open( pathparts[0] + "_part_" + str(outputFileCount) + pathparts[1], "w" )
        outputFile.write( line )
    outputFile.close()
    if( outputFileCount == 1 ) :
        print "Failed: Did not find any of the layers"
        sys.exit()
    if( outputFileCount != len(layers)+1 ) :
        print "Failed: Did not find all of the layers"
        sys.exit()
        
    print "Split file into " + str( outputFileCount ) + " parts"
    

        
    
