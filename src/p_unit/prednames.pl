:- module(prednames, [orig_pred_name/2, orig_goal/2],
	    [assertions, isomodes]).

% Doc added by IG
:- doc(module, "This module is used to get original names of syntactically
	transformed predicates (e.g. to remove cuts or disjunctions).").

:- use_module(library(lists), [reverse/2]).
:- use_module(library(terms), [copy_args/3]).

:- pred orig_pred_name(+Pred, -Orig_Pred) # "@var{Orig_Pred} is the
      predicate name which corresponds to @var{Pred}, which is a
      predicate name generated using @pred{new_predicate}.".
orig_pred_name(Pred, Orig_Pred) :-
	name(Pred, List),
	reverse(List, RList),
	remove_version_id(RList, NRList),
	reverse(NRList, NList),
	name(Orig_Pred, NList).

remove_version_id([0'_|L], L) :- !.
remove_version_id([_|L],   NL) :-
	remove_version_id(L, NL).

:- pred orig_goal(+Goal, -Orig_Goal) # "@var{Orig_Goal} is the goal
     which corresponds to @var{Goal} by replacing the new name of the
     predicate generated by @pred{new_predicate} by the original
     name.".
orig_goal(Goal, Orig_Goal) :-
	functor(Goal, N, A),
	orig_pred_name(N, Orig_N),
	functor(Orig_Goal, Orig_N, A),
	copy_args(A, Goal, Orig_Goal).
