(*
 * Copyright (c) 2014 Daniel C. Bünzli
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

(** Built-in actions for OCaml.

    See {!Assemblage.Action.OCaml}. *)

(** {1 Types} *)

type includes = As_path.t list
type name = As_path.t

(** {1 Preprocess} *)

val compile_src_ast :
  ?needs:As_path.t list -> ?args:string list ->
  dumpast:As_acmd.bin ->
  [`Ml | `Mli] -> src:As_path.t -> unit ->
  As_action.t

(** {1 Compiling} *)

val compile_mli :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlc:As_acmd.bin ->
  annot:bool -> incs:includes -> src:As_path.t -> unit ->
  As_action.t

val compile_ml_byte :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlc:As_acmd.bin ->
  annot:bool -> has_mli:bool -> incs:includes -> src:As_path.t -> unit ->
  As_action.t

val compile_ml_native :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlopt:As_acmd.bin ->
  annot:bool -> has_mli:bool -> incs:includes -> src:As_path.t -> unit ->
  As_action.t

val compile_c :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlc:As_acmd.bin ->
  src:As_path.t -> unit ->
  As_action.t

(** {1 Archiving} *)

val archive_byte :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlc:As_acmd.bin ->
  cmos:As_path.t list -> name:name -> unit ->
  As_action.t

val archive_native :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlopt:As_acmd.bin ->
  cmx_s:As_path.t list -> name:name -> unit ->
  As_action.t

val archive_shared :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlopt:As_acmd.bin ->
  cmx_s:As_path.t list -> name:name -> unit ->
  As_action.t

val archive_c :
  ?needs:As_path.t list -> ?args:string list ->
  ocamlmklib:As_acmd.bin ->
  objs:As_path.t list -> name:name -> unit ->
  As_action.t

(** {1 Linking} *)