open Cil
open Utils
open Sexplib
open Sexplib.Std

module E = Errormsg

type memory = | Data of int
              | Padding of int [@@deriving sexp]

type tsig = memory list [@@deriving sexp]

type sigmap = (tsig, string list) Hashtbl.t [@@deriving sexp]

let signatures : sigmap = Hashtbl.create 3

let sigToStr (t : tsig) =
  listToString (fun s ->
      match s with
      | Data x -> string_of_int x
      | Padding x -> Printf.sprintf "P%d" x) t

let typeToOffsets (t : typ) : tsig =
  match t with
  | TArray (base_type, exp, attrs) ->
     let base_type_size = bitsSizeOf base_type in
     begin
       match exp with
       | None -> []
       | Some e ->
          begin
            match isInteger e with
            | None -> failwith "Expression is not an integer\n"
            | Some i -> repeat (i64_to_int i) (Data base_type_size)
          end
     end
  | TComp (cinfo, _) when cinfo.cstruct ->
     let alignBits = 8 * (alignOf_int t) in
     let (info, _) =
       List.fold_left (fun (offsets, curAlign) field ->
           let tsize = bitsSizeOf field.ftype in
           let nextAlign =
             match tsize mod alignBits with
             | 0 -> 0
             | t -> alignBits - t
           in
           match curAlign with
           | 0 -> ((Data tsize)::offsets, nextAlign)
           | c ->
              begin
                match field.ftype with
                | TInt (IChar, _) ->
                   (* If Char don't add padding *)
                   ((Data 8)::offsets, c - 8)
                | t ->
                   (* Else pad if needed *)
                   ((Data tsize)::(Padding c)::offsets, nextAlign)
              end
         ) ([], 0) cinfo.cfields
     in
     List.rev info
  | _ -> [Data (bitsSizeOf t)]

let addType type_sig name =
  let cur_types = Hashtbl.find_opt signatures type_sig in
  match cur_types with
  | None -> Hashtbl.replace signatures type_sig [name]
  | Some ts when not (List.mem name ts) ->
     Hashtbl.replace signatures type_sig (name::ts)
  | _ -> ()

let getTypenames type_sig =
  match Hashtbl.find_opt signatures type_sig with
  | None -> ["None"]
  | Some ts -> ts

let getAltTypes (type_sig : tsig) =
  let signature_partitions =
    List.filter
      (List.for_all
         (fun s -> Hashtbl.mem signatures s))
      (listPartitions type_sig) in
  List.fold_left (fun type_lists part ->
      let part_types = List.map (fun s -> Hashtbl.find signatures s) part in
      (product part_types)@type_lists
    ) [] signature_partitions

let printTypes () =
  Hashtbl.iter (fun type_sig type_names ->
      E.log "Types with signature [%s]: %s\n"
        (sigToStr type_sig)
        (strListToStr type_names)
    ) signatures

let toFile fname =
  Sexp.save fname (sexp_of_sigmap signatures)

let fromFile fname =
  let s = sigmap_of_sexp (Sexp.load_sexp fname) in
  Hashtbl.iter (fun key v -> Hashtbl.replace signatures key v) s
