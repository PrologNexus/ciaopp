:- module(def, [], [assertions, datafacts, modes_extra]).

:- doc(title, "def: definiteness (abstract domain)").
:- doc(author, "Maria Garcia de la Banda").
:- doc(author, "Manuel Hermenegildo").
:- doc(stability, beta).

:- include(ciaopp(plai/plai_domain)).
:- dom_def(def, [default]).

% TODO: body_succ_builtin/9: (old comment) these do not have special(_), so ok: AbsInt \== def, AbsInt \== fr, AbsInt \== frdef

%% :- doc(bug,"1. length/2 is not working properly.").

:- doc(copyright,"Copyright @copyright{} 1990-94 UPM-CLIP").

% infers(ground/1, rtcheck).
% inters(covered/2, rtcheck).

:- doc(module,"
This file contains the definiteness abstract domain and abstract
unctions for CLP languages.

The abstract constraint is kept as `a(Ground,Set)` in which:
- `Ground` is a sorted list of uniquely defined variables
- `Set` is a sorted list of elements with format (`X`,`SS`) in which
  `X` is a variable and `SS` is a sorted set of set of variables
  such that for each `S` in `SS`, uniquely defining all variables
  in `S`, uniquely defines `X`, and there is no `S'` in `SS`, such that
  `S'` subseteq `S`.
- Not that *top variables* (variables from which nothing is known)
  cannot appear in `Ground` but can appear in some `SS`.

@begin{note}
**Meaning of the Program Variables**                                     
                                                                       
- `AbsInt`   : identifier of the abstract interpreter being used. 
- `Sg`       : Subgoal being analysed.                                      
- `SgKey`    : Subgoal key (represented by functor/arity).                  
- `Sv`       : Subgoal variables.                                           
- `Call`     : Abstract call constraint.                                    
- `Proj`     : Call projected onto `Sv`.                                      
- `Head`     : Head of one of the clauses which define the `Sg` predicate.    
- `Hv`       : Head variables.                                              
- `Fv`       : Free variables in the body of the clause being considered   
- `Entry`    : Abstract entry constraint (i.e. the abstract subtitution    
               obtained after the abstract unification of `Sg` and `Head`     
               projected onto `Hv` + `Fv`).                                     
- `BothEntry`: Similar to the abstract entry constraint: the abstract     
               subtitution obtained after the abstract unification of `Sg`   
               and Head but without being projected onto `Hv` + `Fv`).          
- `Exit`     : Abstract exit constraint (i.e. the abstract subtitution     
               obtained after the analysis of the clause being considered  
               projected onto `Hv`).                                          
- `Prime`    : Abstract prime constraint (i.e. the abstract subtitution    
               obtained after the analysis of the clause being considered  
               projected onto `Sv`).                                          
- `BPrime`   : similar to the abstract prime constraint: abstract          
               subtitution obtained after the analysis of the clause being 
               considered still projected onto `Hv` (i.e. just before going  
               `Sv` and thus, to `Prime`).                                      
- `Succ`     : Abstract success constraint (i.e. the abstract subtitution  
               obtained after the analysis of the clause being considered  
               extended to the variables of the clause in which `Sg` appears).
- `Constr`   : Any abstract constraint.                                     
@end{note}
").
% Some changes made by wims@cs.kuleuven.ac.be 

:- use_module(library(sets), 
    [  merge/3, ord_member/2, ord_subset/2, ord_intersection/3 ]).
:- use_module(library(sort), [sort/2]).
:- use_module(library(terms_check), [variant/2]).
:- use_module(library(terms_vars), [varset/2]).

:- use_module(library(compiler/p_unit), [curr_language/1]).

:- use_module(domain(deftools)).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      ABSTRACT Call To Entry                            %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
:- export(call_to_entry/9).
:- dom_impl(_, call_to_entry/9, [noq]).
:- pred call_to_entry(+Sv,+Sg,+Hv,+Head,+K,+Fv,+Proj,-Entry,-BothEntry)
   #
"It obtains the abstract constraint (`Entry`) which results from adding  
the abstraction of the constraint `Sg` = `Head` to `Proj`,
later projecting the resulting constraint onto `Hv`.                
This is done as follows:
- It will add to `Call` the information corresponding to the set of     
  equations `=`(`ArgSg`,`ArgHead`) resulting from the unification `Sg` = `Head` 
  by calling to `def_herbrand_equation/6`, obtaining `NewProj`.           
- If `NewProj` is `$bottom` (i.e. if `Sg` and `Head` are not
  unifiables) then `Entry` = `bottom`.
  Otherwise, it will project `NewProj` onto `Hv` and it will add the free
  variables in the body of the clause to the projected constraint,
  obtaining `Entry`.
".

call_to_entry(_Sv,Sg,_Hv,Head,_K,_Fv,Proj,Entry,BothEntry):-
    variant(Sg,Head),!,
    copy_term((Sg,Proj),(NewTerm,NewProj)),
    Head = NewTerm,
    abs_sort(NewProj,Entry),
    BothEntry = yes.
call_to_entry(_Sv,Sg,Hv,Head,_K,_Fv,Proj,Entry,BothEntry):-
    def_herbrand_equation(Sg,Head,Proj,NewProj),
    handle_bottom_project(NewProj,Hv,Entry),
    BothEntry = NewProj.

%:- export(handle_bottom_project/3).  % JN needed by sharedef.pl
handle_bottom_project('$bottom',_Hv,Entry):- !,
    Entry = '$bottom'.
handle_bottom_project(NewProj,Hv,Entry):- 
    project(not_provided_Sg,Hv,not_provided_HvFv_u,NewProj,Entry).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      ABSTRACT Exit To Prime                            %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
:- export(exit_to_prime/7).
:- dom_impl(_, exit_to_prime/7, [noq]).
:- pred exit_to_prime(+Sg,+Hv,+Head,+Sv,+Exit,+BothEntry,-Prime)
   #
"It computes the prime abstract constraint `Prime`, i.e.  the result
of going from the abstract constraint over the head variables
(`Exit`), to the abstract constraint over the variables in the subgoal.     
If `Exit` is `$bottom`, `Prime` will be also `$bottom`.          
Otherwise `Prime` is the result of projecting `Exit` onto `Hv`
obtaining `BPrime`, then adding the information in `BPrime` to the
`BothEntry` (the abstract constraint obtained during the
call to entry over all variables in `Sg` and `Head` and later
projecting onto `Sv`.
".

exit_to_prime(_,_,_,_,'$bottom',_,Prime):- !,
    Prime = '$bottom'.
exit_to_prime(Sg,Hv,Head,_,Exit,yes,Prime):- !,
    project(Sg,Hv,not_provided_HvFv_u,Exit,Beta),
    copy_term((Head,Beta),(NewTerm,NewPrime)),
    Sg = NewTerm,
    abs_sort(NewPrime,Prime).
exit_to_prime(Sg,Hv,_,Sv,Exit,BothEntry,Prime):-
    project(Sg,Hv,not_provided_HvFv_u,Exit,BetaPrime),
    def_conjunct_constr(BetaPrime,BothEntry,TempPrime),
    project(Sg,Sv,not_provided_HvFv_u,TempPrime,Prime).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                         ABSTRACT PROJECTION                            %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
:- export(project/5).
:- dom_impl(_, project/5, [noq]).
:- pred project(+Sg,+Vars,+HvFv_u,+Constr,-Projected)
   #
"It projects the ordered abstract subtitution given in the first          
argument on the ordered list of variables `Vars` in the second argument. 
All the variables in the second argument are assumed to appear also    
in the abstract constraint.                                          
- If the abstract constraint is `$bottom` the projected abstract    
  constraint  will be also `$bottom`                               
- Otherwise: let a(`Ground`,`Set`) be the abstract constraint           
  and a(`PGround`, `PSet`) be the result of the projection
  - `PGround` will be the intersection of `Ground` and `Vars`            
  - `PSet` will be the result of for each (`X`,`SS`) in `Set`
     s.t.`X` in `Vars` remove from `SS` those sets which are not
     subsetseq of `Vars` obtaining `NewSS`. This will be done by calling
     `project_vars/5`.
     Note that if `NewSS` is [], (`X`,`NewSS`) will not be in `PSet`
".

project(_Sg,_Vars,_HvFv_u,'$bottom','$bottom') :- !.
project(_Sg,Vars,_HvFv_u,a(Ground,Set),Projected):-
    ord_intersection(Ground,Vars,PGround),  
    project_vars(Vars,Set,Vars,PSet),
    Projected = a(PGround,PSet).

:- export(project_vars/4).
:- pred project_vars(+Vars1,+Set,+Vars2,-PSet)
   #
"It will project the list of (`X`,`SS`) in `Set` onto
`Vars2` obtaining `PSet`.  
This will be done in the following way, for each (`X`,`SS`) in `Set`:
- If `X` not in `Vars1`, (`X`,`SS`) will be eliminated.                    
- Otherwise, we will compute `NewSS` = `\\{` `S` in `SS`| `S` in `Vars2` `\\}`.
  -  If `NewSS` = [], `X` becomes *top* and it will be ignored.
  - Otherwise, (`X`,`NewSS`) will be added to `PSet`.
".

project_vars(_,[],_Vars,[]) :- !.
project_vars([],_Proj,_Vars,[]).
project_vars([Hd1|Tl1],[(Hd2,Value)|Tl2],Vars,Projected) :-
    compare(Ord, Hd1, Hd2),
    project_vars_(Ord,Hd1,Tl1,(Hd2,Value),Tl2,Vars,Projected).

% project_vars(+,+,+,+,+,+,-)
project_vars_(=,Hd,Tl1,(_,Set),Tl2,Vars,Projected) :- !,
    def_project_each(Set,Vars,TempSet),
    decide_top(TempSet,Hd,Projected,NewProjected),
    project_vars(Tl1, Tl2, Vars,NewProjected).
project_vars_(>,Hd1,Tl1,_Hd0,Tl2,Vars,Projected) :-
    project_vars([Hd1|Tl1],Tl2,Vars,Projected).
project_vars_(<,_Hd1,Tl1,Hd2,Tl2,Vars,Projected) :-
    project_vars(Tl1,[Hd2|Tl2],Vars,Projected).

:- pred decide_top(+Set,in_var(X),---Proj,?Tail)
   #
"If `Set` = [], `X` is a top variable and it is ignored.
Otherwise it adds (`X`,`Set`) to `Proj`.
".

decide_top([],_X,Proj,Proj):- !.
decide_top(Set,X,[(X,Set)|Proj],Proj).

:- export(compute_lub/2).
:- dom_impl(_, compute_lub/2, [noq]).
:- pred compute_lub(+ListConstr,-Lub)
   #
"It obtains the *lub* between all abstract constraints which are elements 
of the list given in the first argument. We assume that the abstract  
constraints are ordered and defined over the same set of variables.   
It will be computed recursively by obtaining the *lub* of 2 abstract    
constraints in each iteration in the following way:
- The lub between two abstract constraints one of which is `$bottom` 
  will result in the other abstract constraint                        
- Otherwise, let `Constr1` = a(`G1`,`T1`,`S1`) and `Constr2` = a(`G2`,`T2`,`S2`)
  - `NewG` will be the intersection between `G1` and `G2`.
  - `NewT` will be the union of `T1` and `T2`.
  - `NewS` will be computed by `lub_set/4`.
".     
compute_lub([X],X):- !.
compute_lub([Constr1,Constr2|Xs],Lub):- 
    compute_lub_el(Constr1,Constr2,LubConstr),
    compute_lub([LubConstr|Xs],Lub).

:- export(compute_lub_el/3).
% :- dom_impl(_, compute_lub_el(ASub1,ASub2,ASub), compute_lub_el(ASub1,ASub2,ASub)).
compute_lub_el('$bottom',Constr,Constr):- !.
compute_lub_el(a(G1,S1),a(G2,S2),a(LubG,LubS)):- !,
    ord_intersection(G1,G2,LubG),
    lub_set(S1,S2,G1,G2,LubS).
compute_lub_el(Constr,'$bottom',Constr).

:- pred lub_set(+S1,+S2,-NewT,-NewS,LubL)
   #
"`S1` and `S2` are the third component of two abstract constraints
`L1` and `L2`.
This predicate computes `NewS` the *lub* between the two sets. In doing       
this it will do the following:                                          
  - for each (`X`,`SS1`) in Set1 s.t. there is no (`X`,_) in
    `Set2`, there are two possibilities, `X` is ground in `L2` or
    `X` is @em{top} in `L2`. In the first case (`X`,`SS1`) must
    be in `NewS`, otherwise (`X`,`SS1`) will be eliminated. 
    This will be done by calling @pred{def_remain_if_element_all/3}  
    To detect this `NewT` (the set of top variables in the @em{lub} of `L1`
    and `L2`) is provided. If `X` is in `NewT`, (`X`,`SS1`)
    will be eliminated.   
  - for each (`X`,`SS2`) in `Set2` s.t. there is no (`X`,_) in
    `Set1`, there same can apply.                        
  - for each (`X`,`SS1`) in `Set1` s.t. exists (`X`,`SS2`)
    in `Set2`:
    we will compute the pairwise union of `SS1` and `SS2`, and then         
    we will eliminate the supersets. This will be done by calling       
    `lub_each/3`.
".

lub_set([],[],_,_,[]):- !.
lub_set([],S2,G1,_G2,LubL):- !,
    def_remain_if_element_all(G1,S2,LubL).
lub_set(S1,[],_G1,G2,LubL):- !,
    def_remain_if_element_all(G2,S1,LubL).
lub_set([(X,Tx)|S1],[(Y,Ty)|S2],G1,G2,LubL):-
    compare(Ord,X,Y),
    lub_set_(Ord,X,Tx,S1,Y,Ty,S2,G1,G2,LubL).

%lub_set(+,+,+,+,+,+,+,+,-)
lub_set_(=,X,Tx,S1,_Y,Ty,S2,G1,G2,[(X,Lub)|LubL]):-
    lub_each(Tx,Ty,Lub),
    lub_set(S1,S2,G1,G2,LubL).
lub_set_(<,X,Tx,S1,Y,Ty,S2,G1,G2,LubL):-
    def_remain_if_element(G2,(X,Tx),LubL,NewLubL,NewG2),
    lub_set(S1,[(Y,Ty)|S2],G1,NewG2,NewLubL).
lub_set_(>,X,Tx,S1,Y,Ty,S2,G1,G2,LubL):-
    def_remain_if_element(G1,(Y,Ty),LubL,NewLubL,NewG1),
    lub_set([(X,Tx)|S1],S2,NewG1,G2,NewLubL).

%lub_each(+,+,-).
lub_each(Tx,Ty,Tz):- Tx == Ty,!, Tz = Tx.
lub_each(Tx,Ty,Lub):-
    def_merge(Tx,Ty,Merged),
    sort(Merged,NewMerged),
    def_minimize_each(NewMerged,[],Lub).

:- export(glb/3).      
:- dom_impl(_, glb/3, [noq]). % Not quiet sure this is correct, but looks good... (PBC)
:- pred glb(+Constr1,+Constr2,-Constr).

glb('$bottom',_ASub,ASub3) :- !, ASub3='$bottom'.
glb(_ASub,'$bottom',ASub3) :- !, ASub3='$bottom'.
glb(a(G1,SS1),a(G2,SS2),Conj):-
    merge(G1,G2,Gr),
    def_conjunct_constr(a(Gr,[]),a(G1,SS1),ASub1),
    def_conjunct_constr(a(Gr,[]),a(G2,SS2),ASub2),
    def_conjunct_constr(ASub1,ASub2,Conj).

:- export(abs_sort/2).       
:- dom_impl(_, abs_sort/2, [noq]).
:- pred abs_sort(+Constr,-SortedConstr)
   #
"It sorts the abstract constraint a(`Ground`,`Set`) received as first 
argument. In doing this it will:
- sort the list of variables in `Ground`                            
- for each (`X`,`SS`) in `Set`:
  - sort each `S` in `SS` obtaining `TempSet`.
  - sort `TempSet`.
".

abs_sort('$bottom','$bottom').
abs_sort(a(Ground,Set),a(NewGround,NewSet)):-
    sort(Ground,NewGround),
    sort_set(Set,TempSet),
    sort(TempSet,NewSet).
abs_sort(d(a(Ground,Set),Del),d(a(NewGround,NewSet),Del)):-
    sort(Ground,NewGround),
    sort_set(Set,TempSet),
    sort(TempSet,NewSet).
abs_sort(ac(Asub_u,Fg),ac(Asub,Fg)):-
    abs_sort(Asub_u,Asub).

%sort_set(+,-).
:- pred abs_sort(+Set1,-Set2).
sort_set([],[]).
sort_set([(X,Tx)|Xs],[(X,NewTx)|NewConstr]):-
    sort_list_of_lists(Tx,TempTx),
    sort(TempTx,NewTx),
    sort_set(Xs,NewConstr).

%sort_list_of_lists(+,-)
:- pred sort_list_of_lists(+ListSet1,-ListSet2).
sort_list_of_lists([],[]).
sort_list_of_lists([X|Xs],[Y|Ys]):-
    sort(X,Y),
    sort_list_of_lists(Xs,Ys).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      ABSTRACT Extend                                   %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
:- export(extend/5).
:- dom_impl(_, extend/5, [noq]).
:- pred extend(+Sg,+Prime,+Sv,+Call,-Succ)
   #
"It extends the information given by the new abstract constraint on the 
 subgoal `Prime` (first argument) to the original information about all   
 the clause variables which is contained in `Call`, obtaining `Succ`.
 - If `Prime` is `$bottom`, `Succ` = `$bottom`.
 - Otherwise, the result will be the same as conjunting the new 
   abstract constraint `Prime` with `Call`.
".

extend(_Sg,'$bottom',_Sv,_Call,'$bottom'):- !.
extend(_Sg,Prime,_Sv,Call,Succ):-
    def_conjunct_constr(Prime,Call,Succ).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                   ABSTRACT Call to Success Fact                        %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
:- export(call_to_success_fact/9).
:- dom_impl(_, call_to_success_fact/9, [noq]).
:- pred call_to_success_fact(+Sg,+Hv,+Head,+K,+Sv,+Call,+Proj,-Prime,-Succ)
   #
"It obtains the prime and success constraint for a fact. However, since 
the program are assumed to be normilised, a fact should have all their 
arguments as voids, and therefore `Prime` = `Proj`, and
`Succ` = `Call`.
".

call_to_success_fact(_Sg,_Hv,_Head,_K,_Sv,_Call,'$bottom',Prime,Succ):- !,
    Prime = '$bottom',
    Succ = '$bottom'.
call_to_success_fact(Sg,_Hv,Head,_K,Sv,Call,_Proj,Prime,Succ):-
    def_herbrand_equation(Sg,Head,Call,Succ),
    handle_bottom_project(Succ,Sv,Prime).

%------------------------------------------------------------------------%
%                         HANDLING BUILTINS                              %
%------------------------------------------------------------------------%

:- export(special_builtin/5).
:- dom_impl(_, special_builtin/5, [noq]).
:- pred special_builtin(+SgKey,+Sg,+Subgoal,-Type,---Condvars)
   #
"The predicate succeeds if the `Sgkey` indicates a builtin or a
constraint `Type` indicates the kind of builtin and `Condvars`
contains the info needed for their abstraction.
- Type:  `'$fd_=/2'` |  Condvars: `Sg` |  Meaning: `=/2` builtin              
- Type:  `'$fd_comp/2'` | Condvars: _ | Meaning:  comparisons like `<`,`>`,etc  
- Type:  `'$fd_piii/2'` | Condvars: `Sg` | Meaning:  PrologIII list           
- Type:  `'$fd_fail'` | Condvars: _ | Meaning:  fail, abort,etc          
- Type:  `'$fd_unchanged'` | Condvars: _ | Meaning:  does not affect the info 
-  ....                              
".

special_builtin('=/2',Sg,_,'$fd_=',Sg).
special_builtin('C/3','C'(X,Y,Z),_,'$fd_=','='(X,[Y|Z])).
special_builtin('fail/0',_Sg,_,'$fd_fail',_Condvars).   
special_builtin('#/2',_Sg,_,'$fd_#',_Condvars).   
special_builtin('</2',_Sg,_,Type,_Condvars):-
    curr_language(clp),!,
    Type = '$fd_comp'.
special_builtin('</2',Sg,_,Type,Condvars):-
    curr_language(lp),!,
    Type = '$fd_ground',
    Condvars = Sg.
%% special_builtin('<=/2',_Sg,_,Type,_Condvars):-
%%      curr_language(clp),!,
%%      Type = '$fd_comp'.
special_builtin('=</2',_Sg,_,Type,_Condvars):-
    curr_language(clp),!,
    Type = '$fd_comp'.
special_builtin('=</2',Sg,_,Type,Condvars):-
    curr_language(lp),!,
    Type = '$fd_ground',
    Condvars = Sg.
special_builtin('>/2',_Sg,_,Type,_Condvars):-
    curr_language(clp),!,
    Type = '$fd_comp'.
special_builtin('>/2',Sg,_,Type,Condvars):-
    curr_language(lp),!,
    Type = '$fd_ground',
    Condvars = Sg.
special_builtin('>=/2',_Sg,_,Type,_Condvars):-
    curr_language(clp),!,
    Type = '$fd_comp'.
special_builtin('>=/2',Sg,_,Type,Condvars):-
    curr_language(lp),!,
    Type = '$fd_ground',
    Condvars = Sg.
special_builtin('.<./2',_Sg,_,Type,_Condvars):-
    Type = '$fd_comp'.
special_builtin('.=<./2',_Sg,_,Type,_Condvars):-
    Type = '$fd_comp'.
special_builtin('.>./2',_Sg,_,Type,_Condvars):-
    Type = '$fd_comp'.
special_builtin('.>=./2',_Sg,_,Type,_Condvars):-
    Type = '$fd_comp'.
special_builtin('true/0',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('!/0',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('nl/0',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('nl/1',Sg,_,'$fd_ground',Sg).   
%%% PrologIII
special_builtin('assign/2',Sg,_,'$fd_ground',Sg).
special_builtin('bound_mult/3',Sg,_,'$fd_bound_mult',Sg).
special_builtin('cpu_time/1',Sg,_,'$fd_ground',Sg).
special_builtin('enum/1',Sg,_,'$fd_ground',Sg).
special_builtin('erase/1',Sg,_,'$fd_ground',Sg).
special_builtin('line/0',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('min_value/2',min_value(_X,Y),_,'$fd_ground',Y).
special_builtin('out/1',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('outc/1',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('outl/1',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('outm/1',Sg,_,'$fd_ground',Sg).
special_builtin('outml/1',Sg,_,'$fd_ground',Sg).
special_builtin('recorda/3',recorda(_X,_Y,Z),_,'$fd_ground',Z).
special_builtin('recorded/3',recorded(_X,_Y,Z),_,'$fd_ground',Z).
special_builtin('reset_cpu_time/0',_Sg,_,'$fd_unchanged',_Condvars).
special_builtin('sys_command/1',Sg,_,'$fd_ground',Sg).
special_builtin('val/2',Sg,_,'$fd_ground',Sg).
special_builtin('$::/2',Sg,_,'$fd_$::',Sg).
%%%%%%%% CLP(R)
special_builtin('ctime/1',Sg,_,'$fd_ground',Sg).
special_builtin('dump/1',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('floor/2',Sg,_,'$fd_ground',Sg).   
special_builtin('printf/2',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('inf/2',inf(_X,Y),_,'$fd_ground',Y).   
special_builtin('ztime/0',_Sg,_,'$fd_unchanged',_Condvars).   
%%%%%%%% SICStus
special_builtin('arg/3',Sg,_,'$fd_arg',Sg).
special_builtin('assert/1',_Sg,_,'$fd_unchanged',_Condvars). 
special_builtin('asserta/1',_Sg,_,'$fd_unchanged',_Condvars). 
special_builtin('assertz/1',_Sg,_,'$fd_unchanged',_Condvars). 
special_builtin('display/1',_Sg,_,'$fd_unchanged',_Condvars). 
special_builtin('length/2',length(_,Y),_,'$fd_ground',f(Y)).
special_builtin('functor/3',functor(_,Y,Z),_,'$fd_ground',f(Y,Z)).   
special_builtin('nonzero/1',_Sg,_,'$fd_unchanged',_Condvars).
special_builtin('=../2',Sg,_,'$fd_=..',Sg).   
special_builtin('write/1',_,_,'$fd_unchanged',_).   
special_builtin('write/2',write(X,_),_,'$fd_ground',X).   
special_builtin('read/1',_Sg,_,'$fd_unchanged',_Condvars).   
special_builtin('var/1',Sg,_,'$fd_free',Sg). % needed?
special_builtin('free/1',Sg,_,'$fd_free',Sg).   
special_builtin('nonvar/1',_,_,'$fd_unchanged',_). % needed?
special_builtin('not_free/1',_,_,'$fd_unchanged',_).   
special_builtin('numbervars/3',Sg,_,'$fd_ground',Sg).   
special_builtin('format/2',format(X,_),_,'$fd_ground',f(X)).   
special_builtin('ground/1',Sg,_,'$fd_ground',Sg).
special_builtin('get_code/1',Sg,_,'$fd_ground',Sg).   
special_builtin('get1_code/1',Sg,_,'$fd_ground',Sg).   
special_builtin('put_code/1',Sg,_,'$fd_ground',Sg).   
% SICStus3 (ISO)
special_builtin('=\\=/2',Sg,_,'$fd_ground',Sg).
% SICStus2.x
% special_builtin('=\=/2',Sg,_,'$fd_ground',Sg).
special_builtin('is/2',Sg,_,'$fd_ground',Sg).
special_builtin('integer/1',Sg,_,'$fd_ground',Sg).
special_builtin('sort/2',sort(X,Y),_,'$fd_=',X=Y).
special_builtin('keysort/2',keysort(X,Y),_,'$fd_=',X=Y).
special_builtin('name/2',Sg,_,'$fd_ground',Sg).
special_builtin('repeat/0',_,_,'$fd_unchanged',_).
special_builtin('tab/1',Sg,_,'$fd_ground',Sg).
special_builtin('tab/2',Sg,_,'$fd_ground',Sg).
special_builtin('ttynl/0',_,_,'$fd_unchanged',_).
special_builtin('ttyput/1',Sg,_,'$fd_ground',Sg).
special_builtin('current_op/3',Sg,_,'$fd_ground',Sg).
special_builtin('statistics/2',Sg,_,'$fd_ground',Sg).
% SICStus3 (ISO)
special_builtin('\\==/2',_,_,'$fd_unchanged',_).
% SICStus2.x
% special_builtin('\==/2',_,_,'$fd_unchanged',_).
special_builtin('==/2',X==Y,_,'$fd_=',X=Y).
special_builtin('atomic/1',Sg,_,'$fd_ground',Sg).
special_builtin('atom/1',Sg,_,'$fd_ground',Sg).
special_builtin('$metachoice/1',Sg,_,'$fd_ground',Sg).
special_builtin('$metacut/1',Sg,_,'$fd_ground',Sg).
special_builtin('=:=/2',Sg,_,'$fd_ground',Sg).
special_builtin('@</2',Sg,_,'$fd_ground',Sg).
special_builtin('@>/2',Sg,_,'$fd_ground',Sg).
% added by JN
special_builtin('findall/3',findall(X,_,Z),_,findall,p(X,Z)).  
special_builtin('compare/3',compare(X,_,_),_,'$fd_ground',Vars):-
    varset(X,Vars).
special_builtin('number/1',Sg,_,'$fd_ground',Sg).

:- export(success_builtin/6).
:- dom_impl(_, success_builtin/6, [noq]).
:- pred success_builtin(+Type,+Sv_uns,?Term,+HvFv_u,+Call,-Succ)
   #
"By now, it is tricky since it assumes the following things:
- booleans are still not allowed 
".

success_builtin('$fd_fail',_Sv_uns,_Condvars,_,_Call,'$bottom').
success_builtin('$fd_unchanged',_Sv_uns,_Condvars,_,Call,Call).
success_builtin('$fd_#',_Sv_uns,_Condvars,_,Call,Call).
success_builtin('$fd_comp',_Sv_uns,_Condvars,_,Call,Call).
success_builtin('$fd_ground',_Sv_uns,GroundTerm,_,Call,Succ):-
    varset(GroundTerm,GroundVars),
    def_conjunct_constr(a(GroundVars,[]),Call,Succ).
success_builtin('$fd_free',_Sv_uns,Sg,_,a(G,S),Succ):-
    varset(Sg,Vars),
    ord_intersection(Vars,G,Int),
    ( Int = [] ->
        Succ = a(G,S)
    ; Succ = '$bottom'
    ).
success_builtin('$fd_=..',Sv_uns,'=..'(X,Y),HvFv_u,Call,Succ):-
    var(Y),!,
    success_builtin('$fd_=',Sv_uns,X=Y,HvFv_u,Call,Succ).
success_builtin('$fd_=..',Sv_uns,'=..'(X,Y),HvFv_u,Call,Succ):-
    Y = [Z|W],!,
    varset(Z,Vz),
    def_conjunct_constr(a(Vz,[]),Call,Succ1),
    success_builtin('$fd_=',Sv_uns,X=W,HvFv_u,Succ1,Succ).
success_builtin('$fd_arg',_Sv_uns,arg(X,Y,Z),_,a(G,S),Succ):-
    var(Y),var(Z),!,
    varset(X,Vars),
    sort([Y,Z],Sorted),
    ord_intersection(Sorted,G,Intersect),
    def_decide_arg(Intersect,Vars,Y,Z,a(G,S),Succ).
success_builtin('$fd_arg',_Sv_uns,_,_,_,'$bottom').
success_builtin('$fd_$::',_Sv_uns,'$::'(X,Y),_,a(G,S),Succ):-
    var(X),var(Y),!,
    sort([X,Y],Sorted),
    ord_intersection(Sorted,G,Intersect),
    def_decide_arg(Intersect,[],X,Y,a(G,S),Succ).
success_builtin('$fd_$::',_Sv_uns,_,_,Succ,Succ).
success_builtin('$fd_=',_Sv_uns,=(X,Y),_,Call,Succ):- 
    def_abstract_equation(X,Y,Call,Succ),!.
success_builtin('$fd_=',_Sv_uns,_,_,_Call,'$bottom').
success_builtin('$fd_bound_mult',_Sv_uns,bound_mult(X,Y,Z),_,Call,Succ):- 
    varset(Z,Lin),
    varset([X,Y],NonLin),
    def_numerical_equation0(NonLin,Lin,Call,Succ).
% meta
success_builtin(findall,_Sv_uns,p(X,Z),HvFv_u,a(G,S),Succ):-  %% added by JN
    varset(X,Varsx),
    ord_subset(Varsx,G),!,
    varset(Z,Varsz),
    success_builtin('$fd_ground',_Sv_uns,Varsz,HvFv_u,a(G,S),Succ).
success_builtin(findall,_Sv_uns,_,_,Call,Call).  %% jcf

:- export(input_user_interface/5).  
:- dom_impl(_, input_user_interface/5, [noq]).
:- pred input_user_interface(?InputUser,+Qv,-ASub,+Sg,+MaybeCallASub)
   : term * list * term * term * term
   #
"It translate the query mode given by the user into the internal 
structure.".

input_user_interface(Gv0,_Qv,a(Gv,[]),_Sg,_MaybeCallASub):-
    may_be_var(Gv0,Gv).
%       get_domain(Info,defdeps,[],Dep).

:- export(input_interface/4).  
:- dom_impl(_, input_interface/4, [noq]).
input_interface(ground(X),perfect,Gv0,Gv):-
    varset(X,Vs),
    myappend(Gv0,Vs,Gv).

myappend(Vs,V0,V):-
    var(Vs), !,
    V=V0.
myappend(Vs,V0,V):-
    merge(Vs,V0,V).

may_be_var(X,X):- ( X=[] ; true ), !.

:- export(asub_to_native/5). 
:- dom_impl(_, asub_to_native/5, [noq]).
:- pred asub_to_native(+ASub,+Qv,+OutFlag,-ASub_user,-Comps)
   #
"It translates an internal abstract constraint into something friendly
for the user.".

asub_to_native(ASub,_Qv,_OutFlag,Succ,[]) :-
    asub_to_native_(ASub,Succ).

asub_to_native_(a(Ground,Set),Succ):-
    sort(Ground,G),
    sort_set(Set,S),
    ( G=[] -> Succ=Succ0 ; Succ=[ground(G)|Succ0] ),
    ( S=[] -> Succ0=[] ; defdeps2covered(S,Succ0) ).
asub_to_native_(d(Def,Del),[delay(Del)|Succ]):- % TODO: not available anymore?
    asub_to_native_(Def,Succ).
asub_to_native_(ac(ASub,Flag),[flag(Flag)|Succ]):- % TODO: not available anymore?
    asub_to_native_(ASub,Succ). 

defdeps2covered([],[]).
defdeps2covered([(V,List)|S],Native):-
    defdeps2covered_(List,V,Native,Native0),
    defdeps2covered(S,Native0).

defdeps2covered_([],_,Native,Native).
defdeps2covered_([L|List],V,[covered(V,L)|Native],Native0):-
    defdeps2covered_(List,V,Native,Native0).

%% %-------------------------------------------------------------------------
%% % output_interface(+,+,-)
%% % The readible format still close to the internal formal is identical
%% % in def (just sorted)
%% %-------------------------------------------------------------------------
%% 
%% output_interface('$bottom',_Vars,'$bottom').     
%% output_interface(ac('$bottom',Fg),_Vars,('$bottom',Fg)):-  !.
%% output_interface(ac(d(ACns,Del),Fg),_Vars,Output):- 
%%      abs_sort(ACns,Out),
%%      del_output(ac(Del,Fg),Out,Output).
%% output_interface(d(ACns,Del),_Vars,Output):- 
%%      abs_sort(ACns,Out),
%%      del_output(Del,Out,Output).
%% output_interface(a(Ground,Set),_Vars,a(G,S)):-
%%      sort(Ground,G),
%%      sort_set(Set,S).
%% output_interface([],_Vars,[]).
%% output_interface([Succ],_Vars,OutSucc):- !,
%%      output_interface(Succ,_Vars,OutSucc).
%% output_interface([Succ|LSucc],_Vars,LOutSucc):- 
%%      output_interface0([Succ|LSucc],_Vars,LOutSucc).
%% 
%% output_interface0([Succ|LSucc],_Vars,[OutSucc|LOutSucc]):-
%%      output_interface(Succ,_Vars,OutSucc),
%%      output_interface0(LSucc,_Vars,LOutSucc).
%% output_interface0([],_Vars,[]).

:- export(unknown_call/4).
:- dom_impl(_, unknown_call/4, [noq]).
:- pred unknown_call(+Sg,+Vars,+Call,-Succ)
   #"
Gives the *top* value for the variables `Vars` involved in a literal       
whose definition is not present, and adds this @em{top} value to            
`Call` (it is like conjunting the information in `Call` with the *top*
for a subset of variables)                                                 
In the definiteness analyser, nothing needs to be done.                
".

unknown_call(_Sg,_Vars,Call,Call).

:- export(unknown_entry/3).
:- dom_impl(_, unknown_entry/3, [noq]).
:- pred unknown_entry(+Sg,+Vars,-Call)
   #"
Gives the *top* value for a given set of variables, resulting in the
abstract constraint `Call`. In the definiteeness domain the *top*
abstraction for a set of variables `Vars` is `T` = a(\\{\\},\\{\\}).
".

unknown_entry(_Sg,_Vars,a([],[])).

%------------------------------------------------------------------------%

:- export(empty_entry/3).
:- dom_impl(_, empty_entry/3, [noq]).
:- pred empty_entry(+Sg,+Vars,-Entry).
   
empty_entry(Sg,Qv,Call) :- unknown_entry(Sg,Qv,Call).

:- export(less_or_equal/2).
:- dom_impl(_, less_or_equal/2, [noq]).
:- pred less_or_equal(+ASub0,+ASub1)
   #"
Succeeds if `ASub0` = (`G0`,`T0`,`R0`) is less or equal
than `ASub1` = a(`G1`,`T1`,`R1`)
i.e. if `ASub0` is more concrete or equal than `ASub1`.
This will be true if either `ASub0` is *bottom* or:
- `G1` subseteq `G0`.
- forall (`X`,`SS1`) in `R1`, `X` in `G0`,
  or exists (`X`,`SS0`) in `R0`, such that
  forall `S1` in `SS1`, exists `S0` in `SS0` such that `S0` in
  `S1`.
".
less_or_equal('$bottom',_).
less_or_equal(a(G0,D0),a(G1,D1)):-
    ord_subset(G1,G0),
    less_equal_dep(D1,D0,G0).

less_equal_dep([],_,_).
less_equal_dep([(X,_)|D1],D0,G0):-
    ord_member(X,G0),!,
    less_equal_dep(D1,D0,G0).
less_equal_dep([(X,SS1)|D1],[(Y,SS0)|D0],G0):-
    compare(Order,X,Y),
    less_equal_dep_(Order,(X,SS1),D1,(Y,SS0),D0,ND1,ND0),
    less_equal_dep(ND1,ND0,G0).

less_equal_dep_(=,(_X,SS1),D1,(_Y,SS0),D0,ND1,ND0):-
    each_subset(SS1,SS0),
    ND0 = D0,
    ND1 = D1.
less_equal_dep_(>,Elem,D1,_,D0,[Elem|D1],D0).

each_subset([],_SS1).
each_subset([S0|SS0],SS1):-
    each_subset0(SS1,S0),
    each_subset(SS0,SS1).

each_subset0([S1|_],S0):-
    ord_subset(S0,S1),!.
each_subset0([_|SS1],S0):-
    each_subset0(SS1,S0).

%% %-------------------------------------------------------------------------
%% % check_cond(+,+,+,-)
%% % check_cond(Conds,ACns,Sv,Flag)
%% %-------------------------------------------------------------------------
%% % Conds is a list of elements of the form (Gr,Nv), where Gr and Nv are 
%% % ordered sets of variables. Conds represents the conditions under which 
%% % a subgoal will be woken or delayed.
%% %   * If all variables in Gr and Nv are ground and non-var, respectively,
%% %      w.r.t ACons, Flag = w (the goal is definitely woken)
%% %   * If at least one variable in Gr or Nv is non-ground or variable, 
%% %     respectively, w.r.t. ACons, Flag = d (the goal is definitely delayed)
%% %     Note that the definiteness domain is not capable of uinferring such
%% %     information
%% %   * Otherwise, Flag is the set of abstractions under which the goal will
%% %     be woken (projected over Sv).
%% %-------------------------------------------------------------------------
%% 
%% check_cond(Conds,ACns,Sv,Flag,WConds):-
%%      check_cond_(Conds,ACns,Sv,[],Flag,[],WConds).
%% 
%% check_cond_([],_,_,L,L,WCond,WCond).
%% check_cond_([(Gr,Nv,Eq)|_],a(G1,SS),_,_,Flag,_,WConds):-
%%      merge(Gr,Nv,Vars),
%%      ord_subset(Vars,G1),
%%         def_satif_eq(Eq,G1,SS),!,
%%      Flag = w,
%%      WConds = [(Gr,Nv,Eq)].
%% check_cond_([(Gr,Nv,Eq)|RestV],CAsub,Sv,RestW,Flag,WConds0,WConds):-
%%      def_conjunct_constr(a(Gr,[]),CAsub,WACns1),
%%      project(not_provided_Sg,Sv,not_provided_HvFv_u,WACns1,WACns),
%%      check_cond_(RestV,CAsub,Sv,[WACns|RestW],Flag,[(Gr,Nv,Eq)|WConds0],WConds).
%% 
%% satif_eq([],_,_).
%% satif_eq([eq(X,Y)|Eq],G,SS):-
%%      satif_eq_(X,Y,G,SS),!,
%%      satif_eq(Eq,G,SS).
%% 
%% satif_eq_(X,Y,G,_):-
%%      ord_subset([X,Y],G).
%% satif_eq_(X,Y,_,SS):-
%%      depend(SS,X,Y).
%% 
%% depend([(A,SS)|_],X,Y):-
%%      X == A,
%%      ord_member([Y],SS).
%% depend([(A,SS)|_],X,Y):-
%%      Y == A,
%%      ord_member([X],SS).
%% depend([_|Rest],X,Y):-
%%      depend(Rest,X,Y).
%% 
%% %-------------------------------------------------------------------------
%% % propagate_downwards_closed(+,+,-)
%% % propagate_downwards_closed(ACns1,ACns2,ACns)
%% %-------------------------------------------------------------------------
%% % ACns2 must be more instantiated than ACns1 but some downwards closed
%% % properties might have been lost due to a later lub. Thus, those
%% % properties must be returned to ACns2. This simply amounts to propagate 
%% % groundness from ACns2 to ACns1. An then propagate it back.
%% %-------------------------------------------------------------------------
%% 
%% :- dom_impl(_, propagate_downwards_closed(ASub1,ASub2,ASub), downwards_closed(ASub1,ASub2,ASub)).
%% downwards_closed(a(G1,D1),a(G2,D2),ACns):- 
%%      merge(G1,G2,G),
%%      def_conjunct_constr(a(G,[]),a(G1,D1),Temp),
%%      def_conjunct_constr(Temp,a(G2,D2),ACns).
%% 
%% %------------------------------------------------------------------------%
%% % hash(+,+,-)
%% % hash(ASub,Vars,N)
%% %------------------------------------------------------------------------%
%% % Returns a number which identifies ASub (not uniquely but hopefully 
%% % distinguishably enough)
%% %------------------------------------------------------------------------%
%% 
%% hash('$bottom',_,-2).
%% hash(true,_,0).
%% hash(a(G,SS),Fnv,N):-
%%      \+ \+ 
%%      (  primes(Primes),
%% %%      varset(Fnv,Vars),
%% %%      append(Vars,_,Primes),
%%         append(Fnv,_,Primes),
%%         sum_list(G,0,N0),
%%         hash_SS(SS,1,N1),
%%         N2 is N1-N0,
%%         recorda_internal('$hash',N2,_)
%%         ),
%%      recorded_internal('$hash',N,Ref),
%%      erase(Ref).
%% 
%% collect_all_vars_set([],Vars,Vars).
%% collect_all_vars_set([(X,S)|Xs],Vars0,Vars):-
%%      merge_list_of_lists([[X],Vars0|S],Vars1),
%%      collect_all_vars_set(Xs,Vars1,Vars).
%% 
%% hash_SS([],N,N).
%% hash_SS([(X,SS)|Rest],N0,N):-
%%      N1 is X + N0,
%%      sum_list_of_lists(SS,N1,N2),
%%      hash_SS(Rest,N2,N).
%% 
%% %-------------------------------------------------------------------------
%% % impose_cond(+,+,+,-)
%% % impose_cond(Conds,ACns,Sv,LASub)
%% %-------------------------------------------------------------------------
%% 
%% impose_cond([],_,_,[]).
%% impose_cond([(Gr,_,_)|Rest],Sv,ASub,[ASub1|LASub]):-
%%      def_conjunct_constr(a(Gr,[]),ASub,ASub0),
%%      project(not_provided_Sg,Sv,not_provided_HvFv_u,ASub0,ASub1),
%%      impose_cond(Rest,Sv,ASub,LASub).
%% 
%% %-------------------------------------------------------------------------
%% % real_conjoin(+,+,-)
%% % real_conjoin(ACns1,ACns2,Conj)
%% %-------------------------------------------------------------------------
%% 
%% real_conjoin(_,'$bottom','$bottom'):- !.
%% real_conjoin('$bottom',_,'$bottom').
%% real_conjoin(a(GOld,SSOld),a(GNew,_),Conj):-
%%      merge(GOld,GNew,Gr),
%%      def_conjunct_constr(a(Gr,[]),a(GOld,SSOld),ASub),
%%      def_conjunct_constr(ASub,a(GOld,SSOld),Conj).

% :- dom_impl(_, more_instantiate(ASub1,ASub2), less_or_equal(ASub2,ASub1)).
% :- dom_impl(_, convex_hull(Old,_,Old)).
%
% :- dom_impl(_, del_check_cond(Cond,ASub,Sv,Flag,WConds), check_cond(Cond,ASub,Sv,Flag,WConds)).
%% check_cond(_,_,_,_,_). 
%% downwards_closed(_,_,_).
%% :- dom_impl(_, del_hash(ASub,Vars,N), hash(ASub,Vars,N)).
%% hash(_,_,_).
% :- dom_impl(_, del_impose_cond(LCond,Sv,ASub,LASub), impose_cond(LCond,Sv,ASub,LASub)).
%% impose_cond(_,_,_,_).
%% :- dom_impl(_, del_real_conjoin(ASub1,ASub2,ASub), real_conjoin(ASub1,ASub2,ASub)).
%% real_conjoin(_,_,_).
