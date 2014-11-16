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

let str = Printf.sprintf

(* Metadata *)

type ocaml_interface = [ `Normal | `Opaque | `Hidden ]
type ocaml_unit = [ `Mli | `Ml | `Both ]
type c_unit = [ `C | `H | `Both ]

type kind =
  [ `OCaml of ocaml_unit * ocaml_interface
  | `C of c_unit
  | `Js ]

let pp_kind ppf k = As_fmt.pp_str ppf begin match k with
  | `OCaml _ -> "OCaml" | `C _ -> "C" | `Js -> "JavaScript"
  end

type meta = { kind : kind; dir : As_path.t As_conf.value }
let inj, proj = As_part.meta_key ()
let get_meta unit = As_part.get_meta proj unit
let meta ?(dir = As_conf.(value root_dir)) kind = inj { kind; dir }

let kind unit = (get_meta unit).kind
let dir unit = (get_meta unit).dir

let is_kind k p = match As_part.coerce_if `Unit p with
| None -> None
| Some p as r ->
  match kind p with
  | `OCaml _ when k = `OCaml -> r
  | `C _ when k = `C -> r
  | `Js when k = `Js -> r
  | _ -> None

let ocaml = is_kind `OCaml
let js = is_kind `Js
let c = is_kind `C

(* Check *)

let check p =
  let unit = As_part.coerce `Unit p in
  As_log.warn "%a part check is TODO" As_part.pp_kind (As_part.kind unit);
  As_conf.true_

(* Actions *)

(*
  let unit_file fext env u =
    As_path.(as_rel (As_env.build_dir env // (file (name u)) + fext))

  let unit_args u =
    let pkgs = keep_kind `Pkg (deps u) in
    let pkgs_args = As_args.concat (List.map args pkgs) in
    let libs = keep_kind `Lib (deps u) in
    let lib_args lib =
      let cma = List.filter (As_product.has_ext `Cma) (products lib) in
      let cmxa = List.filter (As_product.has_ext `Cmxa) (products lib) in
      match lib_kind lib with
      | `OCaml ->
          let inc ctxs a = As_product.dirname_to_args ~pre:["-I"] ctxs a in
          let prod ctxs a = As_product.target_to_args ctxs a in
          let cma_inc = List.map (inc [`Compile `Byte; `Link `Byte]) cma in
          let cma_prod = List.map (prod [`Link `Byte]) cma in
          let cmxa_inc = List.map (inc [`Compile `Native;`Link `Native]) cmxa in
          let cmxa_prod = List.map (prod [`Link `Native]) cmxa in
          As_args.concat (cma_inc @ cma_prod @ cmxa_inc @ cmxa_prod)
      | `OCaml_pp ->
          let prod a = As_product.target_to_args [`Pp `Byte; `Pp `Native] a in
          As_args.concat (List.map prod cma)
      | `C ->
          As_args.empty
    in
    As_args.(args env u @@@ pkgs_args @@@ concat (List.map lib_args libs))

  let ocamlpp_ext fext ctx =
    let kind = match fext with `Ml -> "cml" | `Mli -> "cmli" in
    let ctx = match ctx with `Byte -> "byte" | `Native -> "native" in
    `Ext (str "%s-%s" kind ctx)

  let rec ocaml_rules unit env u = match unit with
  | `Mli ->
      [ link_src `Mli env u;
        ocaml_pp `Mli `Byte env u;
        ocaml_compile_mli env u; ]
  | `Ml ->
      [ link_src `Ml env u;
        ocaml_pp `Ml `Byte env u;
        ocaml_pp `Ml `Native env u;
        ocaml_compile_ml_byte env u;
        ocaml_compile_ml_native env u; ]
  | `Both ->
      ocaml_rules `Mli env u @ ocaml_rules `Ml env u
*)

let js_actions unit src_dir dst_dir =
  let actions symlink src_dir dst_dir =
    let name = As_part.name unit in
    let src = As_path.(src_dir / name + `Js) in
    let dst = As_path.(dst_dir / name + `Js) in
    [symlink src dst]
  in
  As_conf.(const actions $ As_action.symlink $ src_dir $ dst_dir)

let c_actions spec unit src_dir dst_dir =
  (* FIXME for C I think we want to distinguish two backends
     one that goes through ocamlc and the other who goes to Conf.cc.
     Maybe this should be reflected in the metadata. *)
  let actions symlink ocamlc ocamlopt native debug warn_error src_dir dst_dir =
    let open As_acmd.Args in
    As_log.warn "Full C unit part support is TODO";
    let has_h, has_c = match spec with
    | `H -> true, false | `C -> false, true | `Both -> true, true
    in
    let name = As_part.name unit in
    let src_h = As_path.(src_dir / name + `H) in
    let src_c = As_path.(src_dir / name + `C) in
    let h = As_path.(dst_dir / name + `H) in
    let c = As_path.(dst_dir / name + `C) in
    (* ccomp is here so that we don't fail if we don't have ocamlc *)
    let ccomp = if native then ocamlopt else ocamlc in
    let args =
      add_if debug "-g" @@ adds_if warn_error [ "-ccopt"; "-Werror" ] @@ []
    in
    add_if has_h (symlink src_h h) @@
    add_if has_c (symlink src_c c) @@
    fadd_if has_c
      (As_action_ocaml.compile_c ~args ~ocamlc:ccomp ~src:c) () @@ []
  in
  As_conf.(const actions $
           As_action.symlink $ As_acmd.bin ocamlc $ As_acmd.bin ocamlopt $
           value ocaml_native $ value debug $ value warn_error $
           src_dir $ dst_dir)

let ocaml_actions spec unit src_dir dst_dir =
  let actions symlink ocamlc ocamlopt debug profile warn_error annot
      byte native src_dir dst_dir =
    let open As_acmd.Args in
    let has_mli, has_ml = match spec with
    | `Mli -> true, false | `Ml -> false, true | `Both -> true, true
    in
    let name = As_part.name unit in
    let src_mli = As_path.(src_dir / name + `Mli) in
    let src_ml = As_path.(src_dir / name + `Ml) in
    let mli = As_path.(dst_dir / name + `Mli) in
    let ml = As_path.(dst_dir / name + `Ml) in
    (* mlicomp is here so that we don't fail if we don't have ocamlc *)
    let mlicomp = if native then ocamlopt else ocamlc in
    let byte_annot = byte && not native (* otherwise it trips make *) in
    let args =
      add_if debug "-g" @@ adds_if warn_error [ "-warn_error"; "+a" ] @@ []
    in
    let incs = [] in (* FIXME *)
    add_if has_mli (symlink src_mli mli) @@
    add_if has_ml (symlink src_ml ml) @@
    fadd_if has_mli
      (As_action_ocaml.compile_mli
         ~ocamlc:mlicomp ~args ~annot ~incs ~src:mli) () @@
    fadd_if (has_ml && byte)
      (As_action_ocaml.compile_ml_byte
         ~ocamlc ~args ~annot:byte_annot ~has_mli ~incs ~src:ml) () @@
    fadd_if (has_ml && native)
      (As_action_ocaml.compile_ml_native
         ~ocamlopt ~args:(add_if profile "-p" @@ args)
         ~annot ~has_mli ~incs ~src:ml) () @@ []
  in
  As_conf.(const actions $
           As_action.symlink $ As_acmd.bin ocamlc $ As_acmd.bin ocamlopt $
           value debug $ value profile $ value warn_error $
           value ocaml_annot $ value ocaml_byte $ value ocaml_native $
           src_dir $ dst_dir)

let actions p =
  let unit = As_part.coerce `Unit p in
  let src_dir = dir unit in
  let dst_dir = As_part.root_path unit in
  match kind unit with
  | `C spec -> c_actions spec unit src_dir dst_dir
  | `Js -> js_actions unit src_dir dst_dir
  | `OCaml (spec, _) -> ocaml_actions spec unit src_dir dst_dir

(* Create *)

let v ?usage ?exists ?args ?needs ?dir name kind =
  let meta = meta ?dir kind in
  As_part.v_kind ?usage ?exists ?args ~meta ?needs ~actions ~check name `Unit