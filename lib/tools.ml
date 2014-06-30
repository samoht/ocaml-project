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
  List.for_all ((<>) "--disable-auto-load-tools") sys_argl

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
       sprintf "[auto-load-tools: %s]"
         (Shell.color `magenta (string_of_bool auto_load)));
  Toploop.initialize_toplevel_env ();
  Toploop.set_paths ();
  let includes =
    if auto_load then
      includes @ Shell.exec_output "ocamlfind query -r tools"
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
  Makefile.(write @@ of_project t ~features ~flags);
  Ocamlfind.META.(write @@ of_project t);
  Opam.Install.(write @@ of_project t)

let describe t _env =
  let deps x = match Dep.filter_pkgs x @ Dep.filter_pkg_pps x with
    | [] -> ""
    | ds -> sprintf "[%s]" (String.concat " " ds) in
  let unit i n u =
    let mk f ext = if f u then (Shell.color `bold @@ Unit.name u) ^ ext else "" in
    let ml = mk Unit.ml ".ml" in
    let mli = mk Unit.mli ".mli" in
    printf "  %s %-25s%-25s\n" (if i = n then "└─" else "├─") ml mli
  in
  let units l =
    let n = List.length l - 1 in
    List.iteri (fun i u ->
        unit i n u
      ) l in
  let lib l =
    printf "├─┬─ %s %s\n" (Shell.color `blue (Lib.id l)) (deps @@ Lib.deps l);
    units (Lib.units l) in
  let pps l =
    printf "├─┬─ %s %s\n" (Shell.color `magenta (Lib.id l)) (deps @@ Lib.deps l);
    units (Lib.units l) in
  let bin b =
    printf "├─┬─ %s %s\n" (Shell.color `cyan (Bin.id b)) (deps @@ Bin.deps b);
    units (Bin.units b)
  in
  printf "\n%s %s %s\n\n"
    (Shell.color `yellow "==>")
    (Shell.color `underline (Project.name t)) (Project.version t);
  List.iter lib (Project.libs t);
  List.iter pps (Project.pps t);
  List.iter bin (Project.bins t)
