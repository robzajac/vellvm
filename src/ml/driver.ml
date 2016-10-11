open Printf
open Platform
open Ollvm
open Ast    

let transform (prog : Ollvm_ast.toplevelentry list) : Ollvm_ast.toplevelentry list =
  Transform.transform prog
  
let print_banner s =
  let rec dashes n = if n = 0 then "" else "-"^(dashes (n-1)) in
  printf "%s %s\n%!" (dashes (79 - (String.length s))) s

let read_file (file:string) : string =
  let lines = ref [] in
  let channel = open_in file in
  try while true; do
      lines := input_line channel :: !lines
  done; ""
  with End_of_file ->
    close_in channel;
    String.concat "\n" (List.rev !lines)

let write_file (file:string) (out:string) =
  let channel = open_out file in
  fprintf channel "%s" out;
  close_out channel

let parse_file filename =
  let program = read_file filename |> 
                Lexing.from_string |>
                Ollvm_parser.toplevelentries Ollvm_lexer.token
  in
  program

let output_file filename ast =
  let open Ollvm_printer in
  let channel = open_out filename in
  toplevelentries  (empty_env ()) (Format.formatter_of_out_channel channel) ast;
  close_out channel


let string_of_file (f:in_channel) : string =
  let rec _string_of_file (stream:string list) (f:in_channel) : string list=
    try 
      let s = input_line f in
      _string_of_file (s::stream) f
    with
      | End_of_file -> stream
  in 
    String.concat "\n" (List.rev (_string_of_file [] f))


(* file processing ---------------------------------------------------------- *)
let link_files : (string list) ref = ref []
let add_link_file path =
  link_files := path :: (!link_files)

let process_ll_file path file =
  let _ = Platform.verb @@ Printf.sprintf "* processing file: %s\n" path in
  let ll_ast = parse_file path in
  let ll_ast' = transform ll_ast in
  let vll_file = Platform.gen_name !Platform.output_path file ".v.ll" in
  let _ = output_file vll_file ll_ast' in
  ()

let process_file path =
  let _ = Printf.printf "Processing: %s\n" path in 
  let basename, ext = Platform.path_to_basename_ext path in
  begin match ext with
    | "ll" -> process_ll_file path basename
    | _ -> failwith @@ Printf.sprintf "found unsupported file type: %s" path
  end

let process_files files =
  List.iter process_file files