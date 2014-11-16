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

open Makefile.Infix
open Assemblage
open Assemblage.Private

let str = Format.asprintf

let warn_no_actions = format_of_string
    "%s@ %a@ part@ exists@ in@ configuration@ but@ has@ no@ action."

(* Makefile generation *)

type gen =
  { proj : Project.t;   (* The project to generate. *)
    dirs : Path.Set.t;  (* Set of directories that need to exist. *)
    rmk : Makefile.t;   (* Reversed makefile definition. *) }

let generator proj =
  { proj; dirs = Path.Set.empty;
    rmk =
      `Blank ::
      (`Comment "Run `make help` to get the list of targets.") ::
      (`Comment (Project.watermark_string proj)) :: []; }

let keys gen =
  (* FIXME example, this is similar to how we used to variablify build actions
     but I'm not sure whether doing this is actually a good idea
     since it could potentially trip other derived configuration values
     that are e.g. testing strings. Also if we keep this it should be
     done in dep order. *)
  let alter k var (rmk, conf as no_alter) =
    if not (Conf.mem conf k) then no_alter else
    let v = Conf.(eval conf (get conf k)) in
    let conf = Conf.set conf k (Conf.const (str "$(%s)" var)) in
    (var =?= [str "%a" Conf.(printer (Key.converter k)) v]) :: rmk, conf
  in
  let rmk, conf =
    (`Blank :: gen.rmk, Project.conf (gen.proj))
    |> alter Conf.ocamlc "OCAMLC"
    |> alter Conf.mkdir "MKDIR"
  in
  { gen with proj = Project.with_conf gen.proj conf; rmk }

let mk_recipe conf ctx args cmds =
  let add_cmd acc cmd =
    let redirect op file acc = match file with
    | None -> acc | Some file -> (Path.to_string file) :: op :: acc
    in
    let cmdline =
      [Acmd.bin_name cmd]
      |> List.rev_append (Acmd.args_with_ctx conf ctx args cmd)
      |> redirect "<"  (Acmd.stdin cmd)
      |> redirect "1>" (Acmd.stdout cmd)
      |> redirect "2>" (Acmd.stderr cmd)
      |> List.rev
    in
    cmdline :: acc
  in
  List.rev (List.fold_left add_cmd [] cmds)

(* TODO check and warn about empty targets and cmds and skip *)
let mk_action gen action =
  let inputs = Action.inputs action in
  let outputs = Action.outputs action in
  let dirs = Path.(Set.elements (Set.of_list (List.rev_map dirname outputs))) in
  let order_only_prereqs = List.rev_map Path.to_string dirs in
  let prereqs = List.(rev (rev_map Path.to_string inputs)) in
  let targets = List.(rev (rev_map Path.to_string outputs)) in
  let recipe =
    let ctx = Action.ctx action in
    let args = Args.append (Project.args gen.proj) (Action.args action) in
    mk_recipe (Project.conf gen.proj) ctx args (Action.cmds action)
  in
  let rule = Makefile.rule ~order_only_prereqs ~targets ~prereqs ~recipe () in
  let rmk = rule :: gen.rmk in
  let dirs = List.fold_left (fun set d -> Path.Set.add d set) gen.dirs dirs in
  { gen with dirs; rmk; }

let mk_part gen p =
  if not (Project.eval gen.proj (Part.exists p)) then gen else
  match (Project.eval gen.proj (Part.actions p)) with
  | [] ->
      Log.warn warn_no_actions (Part.name p) Part.pp_kind (Part.kind p);
      gen
  | actions ->
      let name = Part.name p in
      let kind = Part.kind p in
      let comment = str "%a-%s rules" Part.pp_kind kind name in
      let rmk = `Blank :: `Comment comment :: `Blank :: gen.rmk in
      List.fold_left mk_action { gen with rmk } actions

let mk_gen_dirs gen =
  let add_dir dir gen =
    let prereqs = [] in
    let targets = [Path.to_string dir] in
    let cmd = Conf.(Acmd.mkdir $ const dir) in
    let cmd = Project.eval gen.proj cmd in
    let recipe = [ Acmd.bin_name cmd :: Acmd.args cmd ] in
    let rule = Makefile.rule ~targets ~prereqs ~recipe () in
    let rmk = rule :: gen.rmk in
    { gen with rmk }
  in
  let header = "Build directories rules" in
  let rmk = `Blank :: `Comment header :: `Blank :: gen.rmk in
  Path.Set.fold add_dir gen.dirs { gen with rmk }

let of_project ~setup_files proj =
  let gen = generator proj in
  let gen = keys gen in
  let gen = List.fold_left mk_part gen (Project.parts gen.proj) in
  let gen = mk_gen_dirs gen in
  List.rev gen.rmk