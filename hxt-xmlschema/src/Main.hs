{- |
   Module     : Main
   Copyright  : Copyright (C) 2005-2012 Uwe Schmidt
   License    : MIT

   Maintainer : Uwe Schmidt (uwe@fh-wedel.de)
   Stability  : experimental
   Portability: portable
   Version    : $Id$

-}

module Main

where

import Text.XML.HXT.XMLSchema.Validation
import Text.XML.HXT.XMLSchema.TestSuite

import System ( getArgs )

-- ----------------------------------------

-- | Prints usage text
printUsage :: IO ()
printUsage
  = do
    putStrLn $ "\nUsage:\n\n"
            ++ "validateWithSchema -runTestSuite\n"
            ++ "> Run the hxt-xmlschema test suite (for development purposes).\n\n"
            ++ "validateWithSchema <schemaFileURI> <instanceFileURI>\n"
            ++ "> Test an instance file against a schema file.\n"
    return ()

-- ----------------------------------------

-- | Starts the hxt-xmlschema validator
main :: IO ()
main
  = do
    argv <- getArgs
    case length argv of
      1 -> if argv !! 0 == "-runTestSuite"
             then runTestSuite
             else printUsage
      2 -> validateWithSchema (argv !! 0) (argv !! 1) >>= printSValResult
      _ -> printUsage

