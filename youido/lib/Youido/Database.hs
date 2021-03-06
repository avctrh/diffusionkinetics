{-# LANGUAGE OverloadedStrings, ScopedTypeVariables, DeriveGeneric #-}

module Youido.Database where

import System.Exit (die)
import GHC.Generics
import GHC.Conc
import Data.Maybe

import Data.Aeson
import qualified Data.ByteString.Lazy as BSL
import Control.Exception

import Database.PostgreSQL.Simple

data DatabaseConfig = DatabaseConfig
  { user                   :: String
  , password               :: String
  , host                   :: String
  , port                   :: Integer
  , dbname                 :: String
  , migrations_directory   :: Maybe String
  , num_stripes            :: Maybe Int
  , res_per_stripe         :: Maybe Int
  } deriving (Show, Eq, Generic)

instance FromJSON DatabaseConfig

createConn :: DatabaseConfig -> IO Connection
createConn config = do
   catch (createConn' config)
         (\(e::SomeException) -> do putStrLn $ "Failed to connect to the database, retrying in 10s ... ("++show e++")"
                                    threadDelay $ 10 * 1000 * 1000
                                    createConn' config)


createConn' :: DatabaseConfig -> IO Connection
createConn' config = do
  connect ConnectInfo
    { connectHost     = host     config
    , connectUser     = user     config
    , connectPassword = password config
    , connectDatabase = dbname   config
    , connectPort     = fromInteger $ port config
    }

{-getPool :: DatabaseConfig -> PoolOrConn Connection
getPool dbconfig=
 let poolCfg    = PoolCfg (fromMaybe 2 $ num_stripes dbconfig)
                          (fromMaybe 20 $ res_per_stripe dbconfig)
                          $ 24*60*60
     pool       = PCConn $ ConnBuilder (createConn dbconfig) close poolCfg
 in pool -}

readJSON :: FromJSON a => FilePath -> IO a
readJSON path = do
  configJson <- BSL.readFile path
  case eitherDecode configJson of
    Right config -> return config
    Left err -> do
      die $ "Can't read the config file: " ++ err
