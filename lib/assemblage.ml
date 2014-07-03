(*
 * Copyright (c) 2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Printf
open Project

type tool = t -> Build_env.t -> unit

let sys_argl = Array.to_list Sys.argv

let auto_load () =
  List.for_all ((<>) "--disable-auto-load") sys_argl

let includes () =
  let rec aux acc = function
    | []             -> List.rev acc
    | "-I" :: h :: t -> aux (h::acc) t
    | _ :: t         -> aux acc t in
  aux [] sys_argl

let process ?(file="configure.ml") name fn =
  let includes = includes () in
  let auto_load = auto_load () in
  Shell.show "Loading %s. %s"
    (Shell.color `bold file)
    (if auto_load then "" else
       sprintf "[auto-load: %s]"
         (Shell.color `magenta (string_of_bool auto_load)));
  Toploop.initialize_toplevel_env ();
  Toploop.set_paths ();
  let includes =
    if auto_load then
      includes @ Shell.exec_output "ocamlfind query -r assemblage"
    else
      includes in
  List.iter Topdirs.dir_directory includes;
  if not (Sys.file_exists file) then
    Shell.fatal_error 1 "missing %s." file
  else match Toploop.use_silently Format.std_formatter file with
    | false -> Shell.fatal_error 1 "while loading `%s'." file
    | true  ->
      match Project.list () with
      | [] -> Shell.fatal_error 2 "No projects are registered in `%s'." file
      | ts ->
        let features = List.fold_left (fun acc t ->
            Feature.Set.union (Project.features t) acc
          ) Feature.Set.empty ts in
        let env = Build_env.parse name features in
        List.iter (fun t -> fn t env) ts

let configure `Make t env =
  let features = Build_env.features env in
  let flags = Build_env.flags env in
  let makefile = "Makefile" in
  let build_dir = Build_env.build_dir env in
  Makefile.(write @@ of_project t ~features ~flags ~makefile);
  Ocamlfind.META.(write @@ of_project t);
  Opam.Install.(write @@ of_project ~build_dir t)

let describe t env =
  let print_deps x = match Dep.filter_pkgs x @ Dep.filter_pkg_pps x with
    | [] -> ""
    | ds -> sprintf "  ├─── [%s]\n"
              (String.concat " " (List.map (Shell.color `bold) ds)) in
  let print_modules last ms =
    let aux i n m =
      printf "  %s %s\n"
        (if last && i = n then "└───" else "├───") (Shell.color `cyan m) in
    let n = List.length ms - 1 in
    List.iteri (fun i m -> aux i n m) ms in
  let print_units us =
    let aux i n u =
    let mk f ext =
      if f u then (Shell.color `magenta @@ Comp.name u ^ ext) else "" in
    let ml = mk Comp.ml ".ml" in
    let mli = mk Comp.mli ".mli" in
    printf "  %s %-25s%-25s\n" (if i = n then "└─" else "├─") ml mli;
    let build_dir = Build_env.build_dir env in
    print_modules (i=n) (OCaml.modules ~build_dir u)
    in
    let n = List.length us - 1 in
    List.iteri (fun i u -> aux i n u) us in
  let print_top id deps comps ls =
    let aux l =
      printf "└─┬─ %s\n%s"
        (Shell.color `blue (id l)) (print_deps @@ deps l);
      print_units (comps l) in
    List.iter aux ls in
  let print_libs = print_top Lib.id Lib.deps Lib.comps in
  let print_bins = print_top Bin.id Bin.deps Bin.comps in
  printf "\n%s %s %s\n\n"
    (Shell.color `yellow "==>")
    (Shell.color `underline (Project.name t)) (Project.version t);
  print_libs (Project.libs t);
  print_libs (Project.pps t);
  print_bins (Project.bins t)