(*
 * Copyright (c) 2014 Thomas Gazagnaire <thomas@gazagnaire.org>
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

let str = Format.asprintf

(* Metadata *)

type kind = [ `Lib | `Bin | `Sbin | `Toplevel | `Share | `Share_root
            | `Etc | `Doc | `Stublibs | `Man | `Other of As_path.t ]

let pp_kind ppf kind = As_fmt.pp_str ppf begin match kind with
  | `Lib -> "lib" | `Bin -> "bin" | `Sbin -> "sbin" | `Toplevel -> "toplevel"
  | `Share -> "share" | `Share_root -> "share_root" | `Etc -> "etc"
  | `Doc -> "doc" | `Stublibs -> "stublibs" | `Man -> "man"
  | `Other p -> str "other:%s" (As_path.to_string p)
  end

let name_of_kind = function
| `Other p -> As_path.basename p
| kind -> str "%a" pp_kind kind

type meta = { kind : kind; install : bool }

let inj, proj = As_part.meta_key ()
let get_meta p = As_part.get_meta proj p
let meta ?install kind =
  let install = match install with
  | Some install -> install
  | None -> match kind with `Other _ -> false | _ -> true
  in
  inj { kind; install }

let kind p = (get_meta p).kind
let install p = (get_meta p).install

(* Directory specifiers *)

type spec = As_part.kind As_part.t ->
  (As_path.t -> [ `Keep | `Rename of As_path.rel | `Drop]) As_conf.value

let all _ = As_conf.(const (fun _ -> `Keep))

let keep_if pred = As_conf.const (fun f -> if pred f then `Keep else `Drop)
let file_exts exts _ = keep_if (As_path.ext_matches exts)

let bin p = match As_part.coerce_if `Bin p with
| None -> all p
| Some bin ->
    match As_part_bin.kind bin with
    | `OCaml_toplevel -> (* FIXME *) all p
    | `OCaml ->
        let rename ocaml_native f =
          let rename f = `Rename As_path.(Rel.file (basename (rem_ext f))) in
          match As_path.ext f with
          | Some `Byte when As_part_bin.native bin && ocaml_native -> `Drop
          | Some `Byte -> rename f
          | Some `Native -> rename f
          | _ -> `Drop
        in
        As_conf.(const rename $ value ocaml_native)
    | `C ->
        let is_exec f = As_path.(basename (rem_ext f)) = As_part.name bin in
        keep_if is_exec

let warn_miss_unit = format_of_string
    "Library@ part@ %s:@ no@ compilation@ unit@ found@ for@ product@ %s"

let lib_ocaml lib f = match As_path.ext f with
| None -> `Drop
| Some (`Cma | `Cmxa | `Cmxs | `A | `So | `Dll) -> `Keep
| Some (`Cmx | `Cmi | `Cmti as ext) ->
    let unit_name = As_path.(basename (rem_ext f)) in
    begin match As_part_lib.find_unit unit_name lib with
    | None ->
        As_log.warn warn_miss_unit (As_part.name lib) (As_path.to_string f);
        `Drop
    | Some u ->
        begin match As_part_unit.kind u with
        | `OCaml (_, interface) ->
            begin match ext, interface with
            | `Cmx, `Normal -> `Keep
            | (`Cmi | `Cmti), (`Normal | `Opaque) -> `Keep
            | _ -> `Drop
            end
        | _ -> `Drop
        end
    end
| _ -> `Drop

let lib p = match As_part.coerce_if `Lib p with
| None -> all p
| Some lib ->
    match As_part_lib.kind lib with
    | `C -> file_exts [`Dll; `So; `A] lib
    | `OCaml | `OCaml_pp -> As_conf.(const (lib_ocaml lib))

(* Checks *)

let check p =
  let dir = As_part.coerce `Dir p in
  As_log.warn "%a part check is TODO" As_part.pp_kind (As_part.kind dir);
  As_conf.true_

(* Actions *)

let part_links acc symlink exists dir_root keep part_actions =
  if not exists then acc else
  let outputs = As_action.list_outputs part_actions in
  let add acc output = match keep output with
  | `Drop -> acc
  | `Keep -> symlink output As_path.(dir_root / basename output) :: acc
  | `Rename p -> symlink output As_path.(dir_root // p) :: acc
  in
  List.fold_left add acc outputs

let actions keep p =
  let dir = As_part.coerce `Dir p in
  let add_part acc p =
    As_conf.(const part_links $ acc $ As_action.symlink $ As_part.exists p $
             As_part.root_path dir $ keep p $ As_part.actions p)
  in
  let actions = List.fold_left add_part (As_conf.const []) (As_part.needs p) in
  As_conf.(const List.rev $ actions)

(* Dir *)

let default_keep kind keep = match keep with
| Some keep -> keep
| None ->
    match kind with
    | `Bin -> bin
    | `Lib -> lib
    | _ -> all

let v ?usage ?exists ?args ?keep ?install kind needs =
  let keep = default_keep kind keep in
  let actions = actions keep in
  let meta = meta ?install kind in
  let name = name_of_kind kind in
  As_part.v_kind ?usage ?exists ?args ~meta ~needs ~actions ~check name `Dir