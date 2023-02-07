module Test.Main where
  import Prelude(Unit, class Show, class Eq, ($), (==), (/=), (<>), const, pure, show, discard)

  import Data.Tuple(Tuple(..))

  import Data.Foldable(foldl)
  import Data.List as L

  import Effect
  import Effect.Console

  import MRA.Provenance(Provenance(..), (/\), (\/), (>>))
  import MRA.Data(Data(), makeMap, primString, primInt)
  import MRA.Core(Dataset(), dimensionality, literal_d, lshift_d, map_d, project_d, values)
  import MRA.Combinators(count, map_flatten_values, domain)

  type TestResult = Effect Unit

  assertEqual :: forall a. Show a => Eq a => a -> a -> Effect Unit
  assertEqual l r =
    if l == r then log $ "Pass: " <> show l <> " == " <> show r
    else log $ "FAIL: Expected " <> show l <> " but found " <> show r

  assertNotEqual :: forall a. Show a => Eq a => a -> a -> Effect Unit
  assertNotEqual l r =
    if l /= r then log $ "Pass: " <> show l <> " /= " <> show r
    else log $ "FAIL: " <> show l <> " == " <> show r

  toArray :: forall a. L.List a -> Array a
  toArray = foldl (\as a -> as <> pure a) []

  assertValues :: Array Data -> Dataset -> TestResult
  assertValues a d = assertEqual a (toArray $ values d)

  entuple :: forall a b. a -> b -> Tuple a b
  entuple = Tuple

  infix 6 entuple as ~

  universe :: Dataset
  universe = literal_d $ makeMap [
    primString "olympics" ~ makeMap [
      primInt 1 ~ makeMap [primString "year" ~ primInt 1924, primString "city" ~ primString "Boulder", primString "sport" ~ primString "Skating", primString "country" ~ primString "USA" ],
      primInt 2 ~ makeMap [primString "year" ~ primInt 1926, primString "city" ~ primString "Boulder", primString "sport" ~ primString "Bodybuilding", primString "country" ~ primString "USA"],
      primInt 3 ~ makeMap [primString "year" ~ primInt 1928, primString "city" ~ primString "Billings", primString "sport" ~ primString "Skating", primString "country" ~ primString "USA", primString "gender" ~ primString "M"]
    ] ]

  olympics :: Dataset
  olympics = map_flatten_values $ project_d (primString "olympics") universe

  test_project_d :: TestResult
  test_project_d = do
    assertValues [primInt 1924, primInt 1926, primInt 1928] (project_d (primString "year") olympics)
    assertValues [primString "Boulder", primString "Boulder", primString "Billings"] (project_d (primString "city") olympics)

  test_map_d :: TestResult
  test_map_d = do
    assertValues [primInt 1, primInt 1, primInt 1] (map_d (const $ primInt 1) olympics)

  test_dimensionality :: TestResult
  test_dimensionality = do
    assertEqual 1 (dimensionality olympics)
    assertEqual 2 (dimensionality $ lshift_d olympics)

  test_domain :: TestResult
  test_domain = do
    assertValues [primInt 1, primInt 2, primInt 3] (domain $ project_d (primString "olympics") universe)

  test_provenance :: TestResult
  test_provenance =
    let
      projPrimInt4 = Proj (primInt 4)
      projPrimInt3 = Proj (primInt 3)
      projPrimInt2 = Proj (primInt 2)
    in do
      assertEqual (Value /\ Value) Value
      assertEqual Value (Value \/ Value)

      assertEqual (Nada \/ Value) Value
      assertEqual Value (Nada \/ Value)

      -- primitive equality
      assertEqual projPrimInt4 projPrimInt4
      assertNotEqual projPrimInt4 projPrimInt3

      -- associativity of sums
      assertEqual (projPrimInt4 \/ projPrimInt3) (projPrimInt3 \/ projPrimInt4)

      -- associativity of products
      assertEqual (projPrimInt4 /\ projPrimInt3) (projPrimInt3 /\ projPrimInt4)

      -- non-associativity of seqs
      assertNotEqual (projPrimInt4 >> projPrimInt3) (projPrimInt3 >> projPrimInt4)

      -- distributivity of sums through products
      assertEqual (projPrimInt4 /\ (projPrimInt3 \/ projPrimInt2)) ((projPrimInt4 /\ projPrimInt3) \/ (projPrimInt4 /\ projPrimInt2))

      -- distributivity of sums through seqs
      assertEqual (projPrimInt4 >> (projPrimInt3 \/ projPrimInt2)) ((projPrimInt4 >> projPrimInt3) \/ (projPrimInt4 >> projPrimInt2))

      test_join_keys

  test_join_keys :: TestResult
  test_join_keys = do
    log "Testing join keys"

  test_reduce_d :: TestResult
  test_reduce_d = do
    assertValues [primInt 3] (count olympics)

  test_mra_core :: TestResult
  test_mra_core = do
    log "Testing MRA core"
    test_dimensionality

    test_project_d
    test_map_d
    test_reduce_d

  test_mra_combinators :: TestResult
  test_mra_combinators = do
    log "Testing MRA combinators"
    test_domain

  test_data :: TestResult
  test_data = do
    log "Testing Data"
    test_domain

  main :: Effect Unit
  main = do
    test_data

    test_provenance

    test_mra_core

    test_mra_combinators
