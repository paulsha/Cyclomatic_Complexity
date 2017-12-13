module Main where
import Lib
import Control.Distributed.Process
import Control.Distributed.Process.Backend.SimpleLocalnet
import Control.Distributed.Process.Closure
import Control.Distributed.Process.Node (initRemoteTable)
import Control.Monad
import Network.Transport.TCP (createTransport, defaultTCPParameters)
import System.Environment (getArgs)
import System.Exit
import System.FilePath ((</>), takeExtension)
import System.Directory (doesDirectoryExist, getDirectoryContents, getCurrentDirectory)
import GitFunctions
import Data.List.Split
import Data.Time.Clock


-- Main Thread
main :: IO ()
main = do
    args <- getArgs
    curr <- getCurrentDirectory
    case args of
      ["manager", host, port, repo] -> do
        putStrLn "Starting Node as Manager"
        liftIO $ cloneRepo repo
        let r = splitOn "/" repo
        let repoFolderName = last r
        let workFolder = curr ++ "/" ++ repoFolderName
        backend <- initializeBackend host port rtable
        commits <- getCommits repoFolderName
        start <- getCurrentTime
        startManagerNode commits backend workFolder
        end <- getCurrentTime
        liftIO $ deleteLocalRepo repoFolderName
        let execTime = diffUTCTime end start
        putStrLn $ "Computation timeL" ++ (show execTime) ++ "\n"
      ["worker", host, port] -> do
        putStrLn "Starting Node as Worker"
        backend <- initializeBackend host port rtable
        startSlave backend
      _ -> putStrLn "Bad parameters"

	  
-- Get Files
getFilePaths :: FilePath -> IO [FilePath]
getFilePaths topdir = do
    names <- getDirectoryContents topdir
    let properNames = filter (\f -> head f /= '.' && f /= "argon") names
    paths <- forM properNames $ \name -> do
        let path = topdir </> name
        isDirectory <- doesDirectoryExist path
        if isDirectory
            then getFilePaths path
            else return [path]
    return (concat paths)

	
-- Start Manager
startManagerNode :: [String] -> Backend -> FilePath -> IO ()
startManagerNode  commits backend workFolder = do
    startMaster backend $ \workers -> do
        mapM_ (\commit -> do
            liftIO $ fetchCommit commit workFolder
            files <- liftIO $ getFilePaths workFolder
            let hsFiles = filter (\p -> takeExtension p == ".hs") files
            result <- manager hsFiles workers
            liftIO $ putStrLn $ "Cyclomatic Complexities for Commit ID: " ++ commit ++ "\n"
            liftIO $ putStr result) commits
        terminateAllSlaves backend
