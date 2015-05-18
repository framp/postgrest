module Feature.AuthSpec where

-- {{{ Imports
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON
import Network.HTTP.Types

import SpecHelper
-- }}}

spec :: Spec
spec = beforeAll
  (clearTable "postgrest.auth") . afterAll_ (clearTable "postgrest.auth")
  $ around withApp
  $ describe "authorization" $ do

  it "hides tables that anonymous does not own" $
    get "/authors_only" `shouldRespondWith` 404

  it "indicates login failure (BasicAuth)" $ do
    let auth = authHeaderBasic "postgrest_test_author" "fakefake"
    request methodGet "/authors_only" [auth] ""
      `shouldRespondWith` 401

  it "allows users with permissions to see their tables (BasicAuth)" $ do
    _ <- post "/postgrest/users" [json| { "id":"jdoe", "pass": "1234", "role": "postgrest_test_author" } |]
    let auth = authHeaderBasic "jdoe" "1234"
    request methodGet "/authors_only" [auth] ""
      `shouldRespondWith` 200
      
  it "allows users to login (JWT)" $ do
    _ <- post "/postgrest/users" [json| { "id":"jdoe", "pass": "1234", "role": "postgrest_test_author" } |]
    post "/postgrest/sessions" [json| { "id":"jdoe", "pass": "1234" } |] 
      `shouldRespondWith` ResponseMatcher {
          matchBody = Just [json| {"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoicG9zdGdyZXN0X3Rlc3RfYXV0aG9yIiwiaWQiOiJqZG9lIn0.cDqxhPOYUrp8XSDBrqt_eq52hLIv1XtHBjUICVNzLgM"} |]
        , matchStatus = 201
        , matchHeaders = ["Content-Type" <:> "application/json"]
        }
      
  it "indicates login failure (JWT)" $ do
    _ <- post "/postgrest/users" [json| { "id":"jdoe", "pass": "1234", "role": "postgrest_test_author" } |]
    post "/postgrest/sessions" [json| { "id":"jdoe", "pass": "NOPE" } |] 
      `shouldRespondWith` ResponseMatcher {
          matchBody = Just [json| {"message":"Failed authentication."} |]
        , matchStatus = 401
        , matchHeaders = ["Content-Type" <:> "application/json"]
        }

  it "allows users with permissions to see their tables (JWT)" $ do
    _ <- post "/postgrest/users" [json| { "id":"jdoe", "pass": "1234", "role": "postgrest_test_author" } |]
    let auth = authHeaderJWT "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoicG9zdGdyZXN0X3Rlc3RfYXV0aG9yIiwiaWQiOiJqZG9lIn0.cDqxhPOYUrp8XSDBrqt_eq52hLIv1XtHBjUICVNzLgM"
    request methodGet "/authors_only" [auth] ""
      `shouldRespondWith` 200