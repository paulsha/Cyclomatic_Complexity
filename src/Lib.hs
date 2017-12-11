
{-# LANGUAGE BangPatterns    #-}
{-# LANGUAGE TemplateHaskell #-}
--{-# CPP #-}
module Lib where

import Control.Distributed.Process
import Control.Distributed.Process.Backend.SimpleLocalnet
import Control.Distributed.Process.Closure
import Control.Distributed.Process.Node (initRemoteTable)
import Control.Monad
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import PrimeFactors
import GitFunctions
import System.Environment (getArgs)
import System.Exit
import System.FilePath
type File = String
type Files = [String]
type Master = ProcessId
type WorkQueue = ProcessId

doWork :: String -> IO String
doWork f = start_Argon f

worker :: (Master, WorkQueue) -> Process ()
worker (manager, workQueue) = do
    us <- getSelfPid
    liftIO $ putStrLn $ "Starting worker: " ++ show us
    go us
  where
    go :: ProcessId -> Process ()
    go us = do
      send workQueue us
      receiveWait
        [ match $ \n  -> do
            liftIO $ putStrLn $ "[Node " ++ (show us) ++ "] given work: " ++ show n
            work <- liftIO $ doWork n
            send manager work
            liftIO $ putStrLn $ "[Node " ++ (show us) ++ "] finished work."
            go us
        , match $ \ () -> do
            liftIO $ putStrLn $ "Terminating node: " ++ show us
            return ()
        ]

remotable ['worker]

rtable :: RemoteTable
rtable = Lib.__remoteTable initRemoteTable

manager :: Files -> [NodeId] -> Process String
manager files workers = do
    us <- getSelfPid
    workQueue <- spawnLocal $ do
        
        forM_ files $ \f -> do
            pid <- expect
            send pid f

        forever $ do
            pid <- expect
            send pid ()

    forM_ workers $ \nid -> spawn nid $ $(mkClosure 'worker) (us, workQueue)
    liftIO $ putStrLn $ "[Manager] Workers started.\n"
    getResults $ length files

getResults :: Int -> Process String
getResults = run ""
    where
        run :: String -> Int -> Process String
        run r 0 = return r
        run r n = do
            s <- expect
            run (r ++ s ++ "\n") (n-1)