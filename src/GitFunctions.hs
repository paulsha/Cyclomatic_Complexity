module GitFunctions where

import System.IO
import Data.List.Split
import System.Process
import System.FilePath ((</>))
import System.Directory (doesDirectoryExist, getDirectoryContents, getCurrentDirectory)

start_Argon :: String -> IO String
start_Argon file = command_Pipe("stack", "exec -- argon " ++ file)


command_Pipe :: (String, String) -> IO String
command_Pipe (cmd, args) = do
    (_, Just hout, _, _) <- createProcess(proc cmd $ words args){ std_out = CreatePipe }
    hGetContents hout



deleteLocalRepo :: String -> IO ()
deleteLocalRepo repo = do
    callProcess "rm" ["-rf", repo]
    putStrLn $ repo ++ " removed now that the work is done.\n"
	
getCommits :: String -> IO [String]
getCommits repo =  do
    commits <- command_Pipe("git", "--git-dir " ++ repo ++ "/.git log --pretty=format:'%H' ")
    return $ map strip $ words commits

fetchCommit :: String -> String -> IO ()
fetchCommit commit repo = do
    readCreateProcess ((proc "git" ["reset", "--hard", commit]){ cwd = Just repo}) ""
    return ()

cloneRepo :: String -> IO ()
cloneRepo repo = callProcess "git" ["clone", repo]


strip :: [a] -> [a]
strip [] = []
strip [x] = []
strip xs = tail $ init xs
