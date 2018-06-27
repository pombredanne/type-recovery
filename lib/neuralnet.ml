open Pyutils
open Utils

let py_neuralnet = ref Py.none

(* Takes a list of I/O pairs and generates *)
(* let training_pairs (pairs : (string list * string list) list) = *)

(* Initializes the Python neural net code by adding the vocab *)
let init io_pairs () =
  let input, output = List.split (List.flatten io_pairs) in
  let input_vocab = uniq input in
  let output_vocab = uniq output in
  let ocaml_module = Py.Import.add_module "ocaml" in
  let py_input_vocab = Py.List.of_list_map Py.String.of_string input_vocab in
  let py_output_vocab = Py.List.of_list_map Py.String.of_string output_vocab in
  Py.Module.set ocaml_module "input_vocab" py_input_vocab;
  Py.Module.set ocaml_module "output_vocab" py_output_vocab;
  let convert_io_pair (input, output) =
    let py_input = Py.String.of_string input in
    let py_output = Py.String.of_string output in
    Py.Tuple.of_tuple2 (py_input, py_output)
  in
  let convert_pairs pairs = Py.List.of_list_map convert_io_pair pairs in
  let py_pairs = Py.List.of_list_map convert_pairs io_pairs in
  Py.Module.set ocaml_module "io_pairs" py_pairs;
  py_neuralnet := get_module "python.neuralnet"

let py_train srnn params_srnn sentence =
  let sentence = Py.String.of_string sentence in
  let train = get_python_fun !py_neuralnet "train" in
  let args = [| srnn; params_srnn; sentence |] in
  train args

let test_dynet () =
  let py_run = get_python_fun !py_neuralnet "run" in
  ignore (py_run [| |])
