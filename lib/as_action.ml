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

module Shell = As_shell
module Resolver = As_resolver

open Printf

type custom = {
  dir: string option;
  cmd: string;
}

type t = (Resolver.t -> custom)

let custom ?dir fmt =
  ksprintf (fun cmd ->
      { dir; cmd }
    ) fmt

let run t r =
  let s = t r in
  match s.dir with
  | None   -> Shell.exec "%s" s.cmd
  | Some d -> Shell.in_dir d (fun () -> Shell.exec "%s" s.cmd)

let actions t r =
  let s = t r in
  match s.dir with
  | None   -> [s.cmd]
  | Some d -> [
      sprintf "mkdir -p %s" d;
      sprintf "cd %s && %s" d s.cmd
    ]
