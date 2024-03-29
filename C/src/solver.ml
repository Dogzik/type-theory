open Grammar;;
open Printf;;
open List;;

module Ht = Hashtbl;;


type alg_term =  Atom of int | Impl of alg_term * alg_term;;
type equalution = {left : alg_term; right : alg_term};;

let rec term_to_string_inner term buff = match term with
  | Atom(x) ->  begin
                  Buffer.add_string buff ("t" ^ (string_of_int x));
                  buff
                end
  | Impl(a, b) -> begin
                    Buffer.add_string buff "(";
                    let buff1 = term_to_string_inner a buff in
                    Buffer.add_string buff1 " -> ";
                    let buff2 = term_to_string_inner b buff1 in
                    Buffer.add_string buff2 ")";
                    buff2
                  end
;;

let term_to_string term = begin
  let buff1 = Buffer.create 1488 in
  let buff2 = term_to_string_inner term buff1 in
  Buffer.contents buff2
end;;

let print_eq eq = fprintf stdout "%s = %s\n" (term_to_string eq.left) (term_to_string eq.right);;
let print_expr e = fprintf stdout "%s\n" (string_of_expression e);;


let rec get_system expr ind map_free map_bond = match expr with
  | Var(Name (s)) -> begin
                        let id =  match (Ht.find_opt map_bond s) with
                                    | Some(x) -> x
                                    | None -> match (Ht.find_opt map_free s) with
                                      | Some(y) -> y
                                      | None -> begin
                                                  Ht.add map_free s (ind + 1);
                                                  (ind + 1)
                                                end
                        in
                        ([],  Atom(id), (ind + 1))
                      end
  | Apl(p, q) -> begin
                    let (e_p, t_p, ind_1) = get_system p ind map_free map_bond in
                    let (e_q, t_q, ind_2) = get_system q ind_1 map_free map_bond in
                    let new_e = {left = t_p; right = Impl(t_q, Atom(ind_2 + 1))} in
                    let e = new_e::(List.rev_append e_p e_q) in
                    (e, Atom(ind_2 + 1), (ind_2 + 1))
                  end
  | Lambda(Name(s), p) -> begin
                            Ht.add map_bond s (ind + 1);
                            let (e, t_p, ind_1) = get_system p (ind + 1) map_free map_bond in
                            Ht.remove map_bond s;
                            (e, Impl(Atom(ind + 1), t_p), ind_1)
                          end
;;

let rec has_atom term atom = match term with
  | Atom(b) -> atom = term
  | Impl(a, b) -> (has_atom a atom) || (has_atom b atom)
;;

let bad_equal equal = match equal with
  | {left = Atom(a); right = Impl(b, c)} -> has_atom equal.right equal.left
  | _ -> false
;;

let revert equal = match equal with
  | {left = Impl(a, b); right = Atom(c)} -> {left = equal.right; right = equal.left}
  | _ -> equal
;;

let not_id equal = match equal with
    | {left = Atom(a); right = Atom(b)} when (a = b) -> false
    | _ -> true
;;

let reduct equal = match equal with
  | {left = Impl(a, b); right = Impl(c, d)} -> [{left = a; right = c}; {left = b; right = d}]
  | _ -> [equal]
;;

let rec do_subst rule term = match term with
  | Atom(a) when (rule.left = term) -> rule.right
  | Impl(a, b) -> Impl((do_subst rule a), (do_subst rule b))
  | _ -> term
;;

let is_subst substed equal = match equal with
  | {left = Atom(a); right = b} -> not (Ht.mem substed equal.left)
  | _ -> false
;;

let subst rule equal =  if (rule = equal) then equal
                        else {left = (do_subst rule equal.left); right = (do_subst rule equal.right)};;

let rec solve_system system substed = if (List.exists bad_equal system) then None else begin
  let prev = system in

  let system1 = List.rev_map reduct system in
  let system2 = List.flatten system1 in
  let system3 = List.rev_map revert system2 in
  let system4 = List.filter not_id system3 in
  match (List.find_opt (is_subst substed) system4) with
    | None -> (match (List.compare_lengths prev system4) with
                | 0 -> if (List.for_all2 (=) prev system4) then Some(system4) else solve_system system4 substed
                | _ -> solve_system system4 substed
              )
    | Some(rule) -> begin
                      Ht.add substed (rule.left) true;
                      let system5 = List.rev_map (subst rule) system4 in
                      solve_system system5 substed
                    end
end;;

let rec apply_subst term solution = match term with
  | Atom(x) ->  (match (List.find_opt (fun equal -> equal.left = term) solution) with
                  | None -> term
                  | Some(rule) -> rule.right
                )
  | Impl(a, b) -> Impl((apply_subst a solution), (apply_subst b solution))
;;
