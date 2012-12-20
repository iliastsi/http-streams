--
-- HTTP client for use with io-streams
--
-- Copyright © 2012 Operational Dynamics Consulting, Pty Ltd
--
-- The code in this file, and the program it is a part of, is
-- made available to you by its authors as open source software:
-- you can redistribute it and/or modify it under the terms of
-- the BSD licence.
--

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}

module Network.Http.Types (
    Request(..),
    getHostname,
    Response(..),
    Method(..),
    Headers,
    buildHeaders
) where 

import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as S
import Data.HashMap.Strict (HashMap, empty, insert, foldrWithKey)
import Data.CaseInsensitive (CI, mk, original)

-- | HTTP Methods, as per RFC 2616
data Method
    = GET 
    | HEAD 
    | POST 
    | PUT 
    | DELETE 
    | TRACE
    | OPTIONS 
    | CONNECT 
    | PATCH 
    | Method ByteString
        deriving (Show, Read, Ord)


instance Eq Method where
    GET          == GET              = True
    HEAD         == HEAD             = True
    POST         == POST             = True
    PUT          == PUT              = True
    DELETE       == DELETE           = True
    TRACE        == TRACE            = True
    OPTIONS      == OPTIONS          = True
    CONNECT      == CONNECT          = True
    PATCH        == PATCH            = True
    GET          == Method "GET"     = True
    HEAD         == Method "HEAD"    = True
    POST         == Method "POST"    = True
    PUT          == Method "PUT"     = True
    DELETE       == Method "DELETE"  = True
    TRACE        == Method "TRACE"   = True
    OPTIONS      == Method "OPTIONS" = True
    CONNECT      == Method "CONNECT" = True
    PATCH        == Method "PATCH"   = True
    Method a     == Method b         = a == b
    m@(Method _) == other            = other == m
    _            == _                = False

data Request
    = Request {
        qMethod :: Method,
        qHost :: ByteString,
        qPath :: String,            -- FIXME type
        qAccept :: ByteString,      -- FIXME Headers
        qContentType :: ByteString  -- FIXME Headers
    } deriving (Show)



--
-- | Get the virtual hostname that will be used as the @Host:@ header in
-- the HTTP 1.1 request. Per RFC 2616 § 14.23, this will be of the form
-- @hostname:port@ if the port number is other than the default, ie 80
-- for HTTP.
--
getHostname :: Request -> ByteString
getHostname q = qHost q

type StatusCode = Int

data Response
    = Response {
        pStatusCode :: StatusCode,
        pStatusMsg :: ByteString,
        pHeaders :: Headers
    } deriving (Show)

-- | The map of headers in a 'Request' or 'Response'. Note that HTTP
-- header field names are case insensitive, so if you call 'setHeader'
-- on a field that's already defined but with a different capitalization
-- you will replace the existing value.
{-
    This is a fair bit of trouble just to avoid using a typedef here.
    Probably worth it, though; every other HTTP client library out there
    exposes the gory details of the underlying map implementation, and
    to use it you need to figure out all kinds of crazy imports. Indeed,
    this code used here in the Show instance for debugging has been
    copied & pasted around various projects of mine since I started
    writing Haskell. It's quite tedious, and very arcane! So, wrap it
    up.
-}
newtype Headers = Wrap {
    unWrap :: HashMap (CI ByteString) ByteString
}
instance Show Headers where
    show x = S.unpack $ joinHeaders $ unWrap x

joinHeaders :: HashMap (CI ByteString) ByteString -> ByteString
joinHeaders m = foldrWithKey combine S.empty m

combine :: CI ByteString -> ByteString -> ByteString -> ByteString
combine k v acc =
    S.concat [acc, key, ": ", value, "\n"]
  where
    key = original k
    value = v


{-
    Given a list of key,value pairs, construct a 'Headers' map. This is
    only going to be used by RequestBuilder and ResponseParser,
    obviously. And yes, as usual, we go to a lot of trouble to splice
    out the function doing the work, in the name of type sanity.
-}
buildHeaders :: [(ByteString,ByteString)] -> Headers
buildHeaders hs =
    Wrap result
  where
    result = foldr addHeader empty hs

addHeader
    :: (ByteString,ByteString)
    -> HashMap (CI ByteString) ByteString
    -> HashMap (CI ByteString) ByteString
addHeader (k,v) acc = insert (mk k) v acc
