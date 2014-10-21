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

(** Build rule contexts

    For documentation see {!Assemblage.Context}. *)

(** {1 Contexts} *)

type t =
  [ `Prepare
  | `Dep
  | `Pp of [`Byte | `Native | `Js | `C ]
  | `Compile of [`Intf | `Byte | `Native | `Js | `C ]
  | `Archive of [`Byte | `Native | `Shared | `C | `C_shared]
  | `Link of [`Byte | `Native | `Js | `C]
  | `Run of [`Byte | `Native | `Js | `C]
  | `Test
  | `Doc
  | `Other of string ]

val to_string : t -> string