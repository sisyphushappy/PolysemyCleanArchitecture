module CleanArchitectureSpec where

import Data.List (intercalate)
import Test.Hspec
import Utils
import System.Directory

main :: IO ()
main = hspec spec

spec :: Spec
spec =
  describe "All module dependencies" $ do
    it "comply to the outside-in rule" $ do
      check <- verifyAllDependencies "src"
      check `shouldBe` True

-- | verify the dependencies of all Haskell modules in directory 'dir' (and its sub-directories).
verifyAllDependencies :: FilePath -> IO Bool
verifyAllDependencies dir = do
  allImports <- allImportDeclarations dir
  pure $ all verifyImportDecl allImports

-- | this function verifies all import declarations of a Haskell module.
--   If offending imports are found, a diagnostic error message is produced.
verifyImportDecl :: ModuleImportDeclarations -> Bool
verifyImportDecl (packageFrom, imports) =
  let offending = filter (not . verify packageFrom) imports
   in null offending
        || error
          ( "offending import declaration found in: " ++ ppModule packageFrom
              ++ " referencing modules in outer layers: "
              ++ show (map (ppModule . impMod) offending)
          )
  where
    verify :: ModName -> Import -> Bool
    verify pFrom imp =
      importPackage imp `notElem` packages
        || (modulePackage pFrom, importPackage imp) `elem` allowedDependencies packages

-- this type represents the package structure of a module e.g. Data.Time.Calendar resides in package Date.Time
type Package = String

-- | the list of source packages in descending order from outermost to innermost package in our CleanArchitecture project
packages :: [Package]
packages = ["ExternalInterfaces", "InterfaceAdapters", "UseCases", "Domain"]

-- | for a given list of packages this function produces the set of all allowed dependency pairs between packages.
--   Allowed dependenices according to CleanArchiture:
--   1. imports within the same package
--   2. imports from outer layers to inner layers
allowedDependencies :: [Package] -> [(Package, Package)]
allowedDependencies [] = []
allowedDependencies lst@(p : ps) = zip (repeat p) lst ++ allowedDependencies ps

-- | this function returns the Package information from an Import definition
importPackage :: Import -> Package
importPackage imp = modulePackage (impMod imp)

-- | this function returns the Package information from a ModName definition
modulePackage :: ModName -> Package
modulePackage (q, _m) = intercalate "." (qualifierNodes q)

-- | this function pretty-prints a ModName as a fully qualified module name, e.g. 'Data.Time.Calendar'
ppModule :: ModName -> String
ppModule (q, m) = intercalate "." (qualifierNodes q ++ [m])

-- | this type represents the section of import declaration at the beginning of a Haskell module
type ModuleImportDeclarations = (ModName, [Import])

-- | scan all files under filepath 'dir' and return a list of all their import declarations.
allImportDeclarations :: FilePath -> IO [ModuleImportDeclarations]
allImportDeclarations dir = do
  files <- allFiles dir
  mapM parseFile files

-- | list all files in the given directory and recursively include all sub directories
allFiles :: FilePath -> IO [FilePath]
allFiles dir = do
  files <- listDirectory dir
  let qualifiedFiles = map (\f -> dir ++ "/" ++ f) files
  concatMapM
    ( \f -> do
        isFile <- doesDirectoryExist f
        if isFile
          then allFiles f
          else return [f]
    )
    qualifiedFiles

-- | A version of 'concatMap' that works with a monadic predicate.
concatMapM :: Monad m => (a -> m [b]) -> [a] -> m [b]
concatMapM op = foldr f (pure [])
  where
    f x xs = do x <- op x; if null x then xs else do { xs <- xs; pure $ x ++ xs }
