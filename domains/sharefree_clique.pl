:- module(sharefree_clique, [], [assertions, modes_extra]).

:- doc(title, "CLIQUE-sharing+freeness (abstract domain)").
:- doc(author, "Jorge Navas").
:- doc(copyright,"Copyright @copyright{} 2004-2019 The Ciao Development Team").
:- doc(stability, prod).

:- use_module(domain(sharefree), [obtain_info/4]).
:- include(ciaopp(plai/plai_domain)).
:- dom_def(sharefree_clique, [default]).
:- dom_impl(_, obtain_info/4, [from(sharefree:shfr), noq]).

% infers(ground/1, rtcheck).
% infers(mshare/1, rtcheck).
% infers(var/1, rtcheck).
% infers(clique/1, rtcheck).

:- doc(module,"
This file contains an extension (freeness) of the domain dependent     
abstract functions for the clique-sharing domain.                      

The representation of this domain augments the Clique-sharing domain   
with a third component that keep track of freeness.                    

@begin{note}
The meaning of the variables is defined in `sharefree.pl`.                
@end{note}
").

:- use_module(library(sets), [
    ord_subset/2,
    ord_subtract/3,
    ord_union/3,
    ord_intersection/3,
    ord_member/2,
    merge/3,
    insert/3,
    ord_intersection_diff/4]).
:- use_module(library(sort), [sort/2]).
:- use_module(library(lsets), [
    ord_intersect_lists/2,
    ord_split_lists/4,
    sort_list_of_lists/2,
    merge_list_of_lists/2,
    ord_split_lists_from_list/4]).
:- use_module(library(terms_check), [variant/2]).
:- use_module(library(lists), [list_to_list_of_lists/2]).
:- use_module(library(terms_vars), [varset0/2,varset/2]).

:- use_module(domain(share_amgu_sets), [delete_vars_from_list_of_lists/3]).
:- use_module(domain(sharing_clique), [
    extend/5,
    augment_asub/3,
    glb/3,
    input_interface/4,
    input_user_interface/5,
    less_or_equal/2,
    project/5,
    abs_sort/2,
    widen/4]).
:- use_module(domain(sharing_clique), [
    share_clique_lub_cl/3,
    may_be_var/2,
    eliminate_couples_clique/4]).
:- use_module(domain(share_clique_aux), [
    star_w/2, rel_w/3, irrel_w/3, bin_union_w/3, ord_union_w/3,
    share_clique_normalize/2,
    share_clique_normalize/4]).

:- use_module(domain(s_grshfr), 
    [change_values_insert/4,
     create_values/3,
     change_values_if_differ/5,
     var_value/3,
     projected_gvars/3]).
:- use_module(domain(sharefree_amgu), [augment_asub0/3]).
:- use_module(domain(s_grshfr),
    [collect_vars_freeness/2, member_value_freeness/3]).

:- use_module(domain(sharefree), [special_builtin/5]).
:- use_module(domain(sharefree_clique_aux)).
:- use_module(domain(sharefree_amgu_aux)).

:- use_module(domain(share_aux), [
    eliminate_couples/4,
    append_dl/3,
    if_not_nil/4,
    handle_each_indep/4,
    list_ground/2]).

:- doc(bug,"1. In case of success multivariance the predicate
       eliminate_equivalent/2 must de redefined.").
:- doc(bug,"2. The builtin ==/2 is not defined.").
:- doc(bug,"3. The builtins read/2 and length/2 are defined in a 
       simple way.").
:- doc(bug,"4. The non-redundant version is not working because the 
       semantics of the builtins has not been defined yet.").

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      ABSTRACT Call To Entry                            %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%

:- export(call_to_entry/9).
:- dom_impl(_, call_to_entry/9, [noq]).
:- pred call_to_entry(+,+,+,+,+,+,+,-,?).                     

call_to_entry(_Sv,Sg,_Hv,Head,_K,Fv,Proj,Entry,Flag):-
     variant(Sg,Head),!,
     Flag = yes,
     copy_term((Sg,Proj),(NewTerm,NewProj)),
     Head = NewTerm,
     abs_sort(NewProj,((Temp_cl,Temp_sh),Temp_fr)),
     change_values_insert(Fv,Temp_fr,Entry_fr,f),       
     list_to_list_of_lists(Fv,Temp1),
     merge(Temp1,Temp_sh,New_Temp_sh),
     share_clique_normalize((Temp_cl,New_Temp_sh),Entry_SH),
     Entry = (Entry_SH,Entry_fr).
call_to_entry(_Sv,_Sg,[],_Head,_K,Fv,_Proj,Entry,no):- !,
     list_to_list_of_lists(Fv,Entry_sh),
     change_values_insert(Fv,[],Entry_fr,f),
     share_clique_normalize(([],Entry_sh),Entry_SH),
     Entry = (Entry_SH,Entry_fr).
call_to_entry(_Sv,Sg,Hv,Head,_K,Fv,Proj,Entry,ExtraInfo):-
     peel_equations_frl(Sg,Head,Equations),
     augment_asub(Proj,Hv,ASub),     
     sharefree_clique_iterate(Equations,ASub,(ASub_SH,F)),
     sharing_clique:widen(plai_op,ASub_SH,_,SH),
     sharefree_clique_update_freeness(SH,F,Hv,F1),
     project(Sg,Hv,not_provided_HvFv_u,(SH,F1),Entry0),
     augment_asub(Entry0,Fv,(Entry_SH0,Entry_Fr)),
     share_clique_normalize(Entry_SH0,Entry_SH),
     Entry = (Entry_SH,Entry_Fr),
     Proj = (_,F2),
     ExtraInfo = (Equations,F2),!.
call_to_entry(_Sv,_Sg,_Hv,_Head,_K,_Fv,_Proj,'$bottom',_):-!.


%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      ABSTRACT Exit to Prime                            %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%

:- export(exit_to_prime/7).
:- dom_impl(_, exit_to_prime/7, [noq]).
:- pred exit_to_prime(+,+,+,+,+,+,-).

exit_to_prime(_,_,_,_,'$bottom',_,'$bottom'):-!.
exit_to_prime(Sg,Hv,Head,_Sv,Exit,yes,Prime):- !,
     project(Sg,Hv,not_provided_HvFv_u,Exit,(BPrime_sh,BPrime_fr)),
     copy_term((Head,(BPrime_sh,BPrime_fr)),(NewTerm,NewPrime)),
     Sg = NewTerm,
     abs_sort(NewPrime,(SH_Prime,Fr_Prime)),
     %eliminate_redundancies(SH_Prime,SH_Prime_N),
     %share_clique_normalize(SH_Prime,SH_Prime_N),
     SH_Prime = SH_Prime_N,
     Prime = (SH_Prime_N,Fr_Prime).
exit_to_prime(_Sg,[],_Head,Sv,_Exit,_ExtraInfo,Prime):- !,
     list_ground(Sv,Prime_fr),
     Prime = (([],[]),Prime_fr).
exit_to_prime(Sg,_Hv,_Head,Sv,Exit,ExtraInfo,Prime):-
     ExtraInfo = (Equations,Call_Fr),   
     filter_freeness_with_call(Sv,Call_Fr,New_Sv),
     augment_asub(Exit,New_Sv,ASub),     
     sharefree_clique_iterate(Equations,ASub, (ASub_SH,F)),
     sharing_clique:widen(plai_op,ASub_SH,_,SH),
     sharefree_clique_update_freeness(SH,F,Sv,F1),
     project(Sg,Sv,not_provided_HvFv_u,(SH,F1),(SH_Prime,Prime_Fr)),
     %eliminate_redundancies(SH_Prime,SH_Prime_N),
     %share_clique_normalize(SH_Prime,SH_Prime_N),
     SH_Prime = SH_Prime_N,
     Prime = (SH_Prime_N,Prime_Fr).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                            ABSTRACT AMGU                               %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%

:- dom_impl(_, amgu/4, [noq]).
:- pred amgu(+Sg,+Head,+ASub,-AMGU)
   # "`AMGU` is the abstract unification between `Sg` and `Head`.".

amgu(Sg,Head,ASub,AMGU):-
    peel_equations_frl(Sg, Head,Eqs),
    sharefree_clique_iterate(Eqs,ASub,AMGU),!.

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      ABSTRACT Extend_Asub                              %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
                                    
:- redefining(augment_asub/3).
:- dom_impl(_, augment_asub/3, [noq]).
:- pred augment_asub(+,+,-).

augment_asub(ASub,[],ASub).
augment_asub((SH,F),Vars,(SH1,F1)):-
    sharing_clique:augment_asub(SH,Vars,SH1),
    sharefree_amgu:augment_asub0(F,Vars,F1).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                         ABSTRACT Extend                                %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%

:- redefining(extend/5).                   
:- export(extend/5).
:- dom_impl(_, extend/5, [noq]).
:- pred extend(+Sg,+Prime,+Sv,+Call,-Succ)
   #
"If `Prime` = *bottom*, `Succ` = *bottom*. If `Sv` = [], `Call` = `Succ`.            
Otherwise, `Succ_sh` is computed as in `sharing_clique:extend/4`,          
`Call_fr` is computed by:                                                
- obtainig in `NewGv` the set of variables which have becomed ground.   
- adding this `NewGv` variables to `Prime_fr`, obtaining `Temp1_fr`.        
- obtaining in `BVars` the set of nonground variables in `Succ` which do 
  not belong to `Sg` (ar not in `Sv`).                                    
- Then it obtains in `BVarsf` the subset of `BVars` which are free w.r.t 
  `Call_fr`, and in `Temp2_fr`, the result of adding `X`/`nf` to `Temp1_fr`    
  for the rest of variables in `BVars`.                                 
- If `BVarsf` = [],                                                    
".

extend(_Sg,'$bottom',_Sv,_Call,Succ):- !,
    Succ = '$bottom'.
extend(_Sg,_Prime,[],Call,Succ):- !,
    Call = Succ.
extend(Sg,(Prime_SH,Prime_fr),Sv,(Call_SH,Call_fr),(Succ_SH_N,Succ_fr)):-
%extend_SH
    sharing_clique:extend(Sg,Prime_SH,Sv,Call_SH,Succ_SH),
    Succ_SH = Succ_SH_N,
    %eliminate_redundancies(Succ_SH,Succ_SH_N),
    %share_clique_normalize(Succ_SH,Succ_SH_N),
%extend_fr
    member_value_freeness_differ(Call_fr,NonGvCall,g),
    Succ_SH_N = (Succ_Cl,Succ_Sh),
    merge_list_of_lists(Succ_Cl,NonGvSucc_Cl),
    merge_list_of_lists(Succ_Sh,NonGvSucc_Sh),
    ord_union(NonGvSucc_Cl,NonGvSucc_Sh,NonGvSucc),
    ord_subtract(NonGvCall,NonGvSucc,NewGv),
    change_values_insert(NewGv,Prime_fr,Temp1_fr,g),
    ord_subtract(NonGvSucc,Sv,BVars),
    non_free_vars(BVars,Call_fr,Temp1_fr,BVarsf,Temp2_fr),
    ( BVarsf = [] ->
      Temp3_fr = Temp2_fr
    ; 
      member_value_freeness(Prime_fr,NonFree,nf),
      propagate_clique_non_freeness(BVarsf,NonFree,Succ_SH_N,Temp2_fr,Temp3_fr)
    ),
    add_environment_vars(Temp3_fr,Call_fr,Succ_fr).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                         ABSTRACT PROJECTION                            %
%------------------------------------------------------------------------%
%-------------------------------------------------------------------------

:- redefining(project/5).
:- export(project/5).
:- dom_impl(_, project/5, [noq]).
:- pred project(+Sg,+Vars,+HvFv_u,+ASub,-Proj).

project(_Sg,_,_HvFv_u,'$bottom','$bottom'):- !.
project(Sg,Vars,HvFv_u,(SH,F),(Proj_SH,Proj_F)) :-
    sharing_clique:project(Sg,Vars,HvFv_u,SH,Proj_SH),
    project_freeness(Vars,F,Proj_F).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                         ABSTRACT SORT                                  %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%

:- pred abs_sort(+Asub,-Asub_s)
   # "Sorts the set of set of variables `ASub` to obtaint the `Asub_s`.".

:- redefining(abs_sort/2).                     
:- export(abs_sort/2).
:- dom_impl(_, abs_sort/2, [noq]).
abs_sort('$bottom','$bottom'):- !.
abs_sort((SH,F),(Sorted_SH,Sorted_F) ):-
    sharing_clique:abs_sort(SH,Sorted_SH),
    sort(F,Sorted_F).

:- export(identical_abstract/2).
:- dom_impl(_, identical_abstract/2, [noq]).
:- pred identical_abstract(+ASub0,+ASub1)
   #
"Succeeds if the two abstract substitutions are defined on the same     
variables and are equivalent.                                           
".

identical_abstract('$bottom','$bottom'):-!.
identical_abstract('$bottom',_):- !,fail.
identical_abstract(_,'$bottom'):- !,fail.
identical_abstract(ASub0,ASub1):-
    ASub0 == ASub1,!.
identical_abstract((SH0,Fr0),(SH1,Fr1)):-
    Fr0  == Fr1,!,
    share_clique_normalize(SH0,100,1,NSH0),!,
    ( NSH0 == SH1 ->
      true
    ;
      share_clique_normalize(SH1,100,1,NSH1),
      NSH0 == NSH1
    ).

:- dom_impl(_, eliminate_equivalent/2, [noq]).
:- pred eliminate_equivalent(+TmpLSucc,-LSucc)
   #
"The list `LSucc` is reduced wrt the list `TmpLSucc` in that it             
does not contain abstract substitutions which are equivalent.          
".

eliminate_equivalent(TmpLSucc,Succ):-
    sort(TmpLSucc,Succ).

% eliminate_equivalent(TmpLSucc,Succ):-
%       sort(TmpLSucc,TmpLSucc1),
%       normalize_fr_abstract_substitutions(TmpLSucc1,Succ).

% normalize_fr_abstract_substitutions([],[]).
% normalize_fr_abstract_substitutions([(SH,Fr)|Ss],[(NSH,NFr)|Res]):-
%       share_clique_normalize(SH,100,1,NSH),
%       sort(Fr,NFr),
%         normalize_fr_abstract_substitutions(Ss,Res).

:- export(less_or_equal/2).
:- dom_impl(_, less_or_equal/2, [noq]).
:- pred less_or_equal(+ASub0,+ASub1)
   # "Succeeds if `ASub1` is more general or equal to `ASub0`.".

less_or_equal('$bottom',_ASub):- !.
less_or_equal((SH0,Fr0),(SH1,Fr1)):-
    sharing_clique:less_or_equal(SH0,SH1),
    member_value_freeness(Fr0,ListFr0,f),
    member_value_freeness(Fr1,ListFr1,f),
    ord_subset(ListFr1,ListFr0).
    
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      ABSTRACT Call to Success Fact                     |
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%

%% sharefree_call_to_success_fact(_Sg,[],_Head,Sv,Call,_Proj,Prime,Succ) :- 
%%      Call = (Call_SH,Call_fr),!,
%%      update_lambda_cf(Sv,Call_fr,Call_SH,Succ_fr,Succ_SH),
%%      list_ground(Sv,Prime_fr),
%%      Prime = ([],Prime_fr),
%%      %sharing_clique:normalize(Succ_SH,Succ_SH_R),
%%      Succ_SH = Succ_SH_R,
%%      Succ = (Succ_SH_R,Succ_fr).

:- export(call_to_success_fact/9).
:- dom_impl(_, call_to_success_fact/9, [noq]).
:- pred call_to_success_fact/9
   # "Specialized version of `call_to_entry` + `exit_to_prime` + `extend` for facts.".

call_to_success_fact(Sg,Hv,Head,_K,Sv,Call,_Proj,Prime,Succ):-
% exit_to_prime
    augment_asub(Call,Hv,ASub),    
    peel_equations_frl(Sg, Head,Equations),
    sharefree_clique_iterate(Equations,ASub,(ASub_SH,F)),
    sharing_clique:widen(plai_op,ASub_SH,_,SH),
    %share_clique_normalize(SH,SH_N),
    SH = SH_N,
    ASub = (_,Vars), % Vars has both Sv and Hv
    unmap_freeness_list(Vars,Vars1),
    sharefree_clique_update_freeness(SH_N,F,Vars1,F1),
    ASub1=(SH_N,F1),
    project(Sg,Sv,not_provided_HvFv_u,ASub1,Prime),
% extend
    delete_variables(Hv,ASub1,Succ),!.
call_to_success_fact(_Sg,_Hv,_Head,_K,_Sv,_Call,_Proj, '$bottom','$bottom').

delete_variables(Vars,((Cl,Sh),Fr),((New_Cl,New_Sh),New_Fr)):-
    delete_vars_from_list_of_lists(Vars,Sh,Sh0),
    sort_list_of_lists(Sh0,New_Sh),
    delete_vars_from_list_of_lists(Vars,Cl,Cl0),
    sort_list_of_lists(Cl0,New_Cl), 
    delete_variables_freeness(Fr,Vars,New_Fr).

delete_variables_freeness([],_,[]).
delete_variables_freeness([X/_|Xs],Vars,Res):-
    ord_member(X,Vars),!,
    delete_variables_freeness(Xs,Vars,Res).
delete_variables_freeness([X/V|Xs],Vars,[X/V|Res]):-
    delete_variables_freeness(Xs,Vars,Res).


%------------------------------------------------------------------------%
% Specialised version of share_call_to_success_fact in order to allow    |
% the computation of the prime, the composition and then the extension   |
% Note that if the success is computed (instead of the prime) and then   |
% we compose the information and project it, we can loose information    |
% since the extension is the step in which more information is lost      |
%------------------------------------------------------------------------%
call_to_prime_fact(Sg,Hv,Head,Sv,(_SH,Extra_Info),Prime) :-
    augment_asub((_SH,Extra_Info),Hv,Exit),
    exit_to_prime(Sg,Hv,Head,Sv,Exit,Extra_Info,Prime).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                          ABSTRACT LUB                                  %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%

:- dom_impl(_, compute_lub/2, [noq]).
:- pred compute_lub(+ListASub,-Lub)
   #
"It computes the *lub* of a set of `Asub`. For each two abstract           
substitutions `ASub1` and `ASub2` in `ListASub`, obtaining the *lub* is just  
merging the `ASub1` and `ASub2`.                                          
".

compute_lub([ASub1,ASub2|Rest],Lub) :- !,
    compute_lub_el(ASub1,ASub2,ASub3),
    compute_lub([ASub3|Rest],Lub).
compute_lub([ASub],ASub).

:- export(compute_lub_el/3).
% :- dom_impl(_, compute_lub_el(ASub1,ASub2,ASub), compute_lub_el(ASub1,ASub2,ASub)).
compute_lub_el('$bottom',ASub,ASub):- !.
compute_lub_el(ASub,'$bottom',ASub):- !.
compute_lub_el((Cl1,Fr1),(Cl2,Fr2),(Lub_cl,Lub_fr)):- !,
    share_clique_lub_cl(Cl1,Cl2,Lub_cl),
    compute_lub_fr(Fr1,Fr2,Lub_fr).
compute_lub_el(ASub,_,ASub).

% defined in sharefree.pl, it should be exported by share.pl
compute_lub_fr(Fr1,Fr2,Lub):- 
    Fr1 == Fr2, !,
    Lub = Fr1.
compute_lub_fr([Xv|Fr1],[Yv|Fr2],Lub):- 
    Xv == Yv, !,
    Lub = [Xv|Lub_fr],
    compute_lub_fr(Fr1,Fr2,Lub_fr).
compute_lub_fr([X/_|Fr1],[X/_|Fr2],[X/nf|Lub_fr]):-
    compute_lub_fr(Fr1,Fr2,Lub_fr).

:- pred glb(+ASub0,+ASub1,-Lub)
   # "`Glb` is just intersection.".

:- export(glb/3).
:- dom_impl(_, glb/3, [noq]).
glb('$bottom',_ASub,ASub3) :- !, ASub3='$bottom'.
glb(_ASub,'$bottom',ASub3) :- !, ASub3='$bottom'.
glb((SH1,Fr1),(SH2,Fr2),Glb):-
    member_value_freeness(Fr1,FVars1,f),
    member_value_freeness(Fr2,FVars2,f),
    member_value_freeness(Fr1,GVars1,g),
    member_value_freeness(Fr2,GVars2,g),
    ord_intersection(FVars1,GVars2,Empty1),
    ord_intersection(FVars2,GVars1,Empty2),
    ( (Empty1 \== []; Empty2 \== [])
    -> Glb = '$bottom'
     ; merge(FVars1,FVars2,FVars),
       merge(GVars1,GVars2,GVars0),
       sharing_clique:glb(SH1,SH2,Glb_SH),
       varset(Fr1,All),
       Glb_SH = (Gb_Cl,Gb_Sh),
       varset(Gb_Cl,Gb_ClVx),
       varset(Gb_Sh,Gb_ShVx),
       ord_union(Gb_ClVx,Gb_ShVx,Now),
       ord_subtract(All,Now,NewGVars),
       merge(GVars0,NewGVars,GVars),
       ord_intersection(FVars,GVars,Empty),
       ( Empty \== []
       -> Glb = '$bottom'
        ; Glb = (Glb_SH,Glb_fr),
          change_values_insert(FVars,Fr1,TmpFr,f),
          change_values_insert(GVars,TmpFr,Glb_fr,g)
    )  ).

:- export(input_user_interface/5).
:- dom_impl(_, input_user_interface/5, [noq]).
:- pred input_user_interface(?InputUser,+Qv,-ASub,+Sg,+MaybeCallASub)
   : term * list * term * term * term
   #
"Obtaining the abstract substitution for `Cl`+`Fr` from the user supplied   
information just consists in taking the cliques first and the `var(Fv)`  
element of `InputUser`, and construct from them the `Freeness`.            
".

input_user_interface((SH,Fv0),Qv,(Call_SH,Call_fr),Sg,MaybeCallASub):-
    sharing_clique:input_user_interface(SH,Qv,Call_SH,Sg,MaybeCallASub),
%% freeness  
    may_be_var(Fv0,Fv),
    Call_SH = (Cl,Sh),
    merge_list_of_lists(Cl,SH1v),                                           
    merge_list_of_lists(Sh,SH2v),
    ord_union(SH1v,SH2v,SHv),
    ord_subtract(Qv,SHv,Gv),
    ord_subtract(SHv,Fv,NonFv),
    create_values(Fv,Temp1,f),
    change_values_insert(NonFv,Temp1,Temp2,nf),
    change_values_insert(Gv,Temp2,Call_fr,g).

:- export(input_interface/4).
:- dom_impl(_, input_interface/4, [noq]).
input_interface(free(X),perfect,(SH,Fr0),(SH,Fr)):-
    var(X),
    myinsert(Fr0,X,Fr).
input_interface(Prop,Any,(SH0,Fr),(SH,Fr)):-
    sharing_clique:input_interface(Prop,Any,SH0,SH), !.

myinsert(Fr0,X,Fr):-
    var(Fr0), !,
    Fr = [X].
myinsert(Fr0,X,Fr):-
    insert(Fr0,X,Fr).

:- dom_impl(_, asub_to_native/5, [noq]).
:- pred asub_to_native(+ASub,+Qv,+OutFlag,-ASub_user,-Comps)
   #
"The user friendly format consists in extracting the ground variables   
and the free variables                                                 
".

asub_to_native((SH,Fr),_Qv,_OutFlag,Info,[]):-
    SH = (Cl,Sh),
    if_not_nil(Cl,clique(Cl),Info,Info0),
    if_not_nil(Sh,sharing(Sh),Info0,Info1),
    member_value_freeness(Fr,Fv,f),
    if_not_nil(Fv,free(Fv),Info1,Info2),
    member_value_freeness(Fr,Gv,g),
    if_not_nil(Gv,ground(Gv),Info2,[]).

:- export(unknown_call/4).
:- dom_impl(_, unknown_call/4, [noq]).
:- pred unknown_call(+Sg,+Vars,+Call,-Succ).

unknown_call(_Sg,_Vars,'$bottom','$bottom') :- !.
unknown_call(_Sg,Vars,(Call_SH,Call_fr),(Succ_SH,Succ_fr)):-
    rel_w(Vars,Call_SH,Intersect),
    irrel_w(Vars,Call_SH,Rest),
    star_w(Intersect,Star),
    ord_union_w(Star,Rest,Succ_SH),
    Intersect = (Int_Cl,Int_Sh),
    ord_union(Int_Cl,Int_Sh,Int_All),       
    merge_list_of_lists(Int_All,Nonfree_vars),
    change_values_if_f(Nonfree_vars,Call_fr,Succ_fr,nf).

:- export(empty_entry/3).
:- dom_impl(_, empty_entry/3, [noq]).
:- pred empty_entry(+Sg,+Vars,-Entry)
   #
"The empty value in `Sh` for a set of variables is the list of singletons,
in `Fr` is `X`/`f` forall `X` in the set of variables.                                     
".

empty_entry(_Sg,Qv,Entry):-
    list_to_list_of_lists(Qv,Entry_sh),     
    create_values(Qv,Entry_fr,f),
    Entry=(([],Entry_sh),Entry_fr).

:- dom_impl(_, unknown_entry/3, [noq]).
:- pred unknown_entry(+Sg,+Qv,-Call)
   #
"The *top* value in `Sharing` for a set of variables is the powerset, in `Fr` 
`X`/`nf` forall `X` in the set of variables.                                     
".

unknown_entry(_Sg,Qv,Call):-
    sort(Qv,QvS),
    create_values(Qv,Call_fr,nf),
    Call = (([QvS],[]),Call_fr).

%------------------------------------------------------------------------%
%                         HANDLING BUILTINS                              %
%------------------------------------------------------------------------%

:- export(special_builtin/5).
:- dom_impl(_, special_builtin/5, [noq]).
:- pred special_builtin(+SgKey,+Sg,+Subgoal,-Type,---Condvars)
   #
"Satisfied if the builtin does not need a very complex action. It      
divides builtins into groups determined by the flag returned in the    
second argument + some special handling for some builtins:             
- *new_ground* if the builtin makes all variables ground whithout      
  imposing any condition on the previous freeness values of the      
  variables.                                                          
- *old_ground* if the builtin requires the variables to be ground.     
- *old_new_ground* if the builtin requires some variables to be       
  ground and grounds the rest.                                        
- *unchanged* if we cannot infer anything from the builtin, the        
  substitution remains unchanged and there are no conditions imposed 
  on the previo.
- *some* if it makes some variables ground without imposing conditions. 
- *all_nonfree* if the builtin makes all variables possible non free.    
- `Sgkey`, special handling of some particular builtins.                
".

special_builtin('read/2',read(X,Y),_,'recorded/3',p(Y,X)) :- !.
special_builtin('length/2',length(_X,Y),_,some,[Y]) :- !.
special_builtin('==/2',_,_,_,_):- !, fail.
special_builtin(SgKey,Sg,Subgoal,Type,Condvars):-
    sharefree:special_builtin(SgKey,Sg,Subgoal,Type,Condvars).
    
:- dom_impl(_, success_builtin/6, [noq]).
:- pred success_builtin(+Type,+Sv_u,?Condv,+HvFv_u,+Call,-Succ)
   #
"Obtains the success for some particular builtins:                      
- If `Type` = *new_ground*, it updates `Call` making all vars in `Sv_u` ground.
- If `Type` = *bottom*, `Succ` = `$bottom`.                                  
- If `Type` = *unchanged*, `Succ` = `Call`.                                    
- If `Type` = *some*, it updates `Call` making all vars in `Condv` ground.     
- If `Type` = *old_ground*, if grouds all variables in `Sv` and checks that 
              no free variables has becomed ground.                      
- If `Type` = *old_ground*, if grounds all variables in `OldG` and checks   
              that no free variables has becomed ground. If so, it       
              grounds all variables in `NewG`.                             
- If `Type` = *all_non_free* it projects `Call` onto this variables,      
              obtains the closure under union for the `Sh`, changes in    
              `Fr` all `f` to `nf` and later extends the result.               
- Otherwise `Type` is the `SgKey` of a particular builtin for each the   
  `Succ` is computed.                                                   
".
%------------------------------------------------------------------------%
% NOTE: In comparison with shfr, the following builtins are not defined: |
% - list/1                                                               |
%------------------------------------------------------------------------%

success_builtin(new_ground,Sv_u,_,_,Call,Succ):-
    sort(Sv_u,Sv),
    Call = (Lda_SH,Lda_fr),
    update_lambda_cf(Sv,Lda_fr,Lda_SH,Succ_fr,Succ_SH), 
    Succ = (Succ_SH,Succ_fr).
success_builtin(bottom,_,_,_,_,'$bottom').
success_builtin(unchanged,_,_,_,Lda,Lda).
success_builtin(some,_Sv,NewGr,_,Call,Succ):-
    Call = (Call_SH,Call_fr),
    update_lambda_cf(NewGr,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin(old_ground,Sv_u,_,_,Call,Succ):-
    sort(Sv_u,Sv),
    Call = (Call_SH,Call_fr),
    update_lambda_clique_non_free(Sv,Call_fr,Call_SH,Succ_fr,Succ_SH),!,
    Succ = (Succ_SH,Succ_fr).
success_builtin(old_ground,_,_,_,_,'$bottom').
success_builtin(old_new_ground,_,(OldG,NewG),_,Call,Succ):-
    Call = (Call_SH,Call_fr),
    update_lambda_clique_non_free(OldG,Call_fr,Call_SH,Temp_fr,Temp_SH),!,
    update_lambda_cf(NewG,Temp_fr,Temp_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin(old_new_ground,_,_,_,_,'$bottom').
success_builtin(all_nonfree,Sv_u,Sg,_,Call,Succ):- !,
    sort(Sv_u,Sv),
    project(Sg,Sv,not_provided_HvFv_u,Call,(Proj_SH,Proj_fr)),!,
    star_w(Proj_SH,Prime_SH),
    change_values_if_f(Sv,Proj_fr,Prime_fr,nf),
    extend(Sg,(Prime_SH,Prime_fr),Sv,Call,Succ).
% special builtins
success_builtin(arg,_,Sg0,_,Call,Succ):- Sg0=p(X,Y,Z),
    Call = (Call_SH,Call_fr),
    varset(X,OldG),
    update_lambda_clique_non_free(OldG,Call_fr,Call_SH,Temp_fr,Temp_SH),
    var_value(Temp_fr,Y,Value),
    Value \== f,!,
    Sg = p(Y,Z),
    Head = p(f(A,_B),A),
    varset(Sg,Sv),
    varset(Head,Hv),
    TempASub = (Temp_SH,Temp_fr),
    project(Sg,Sv,not_provided_HvFv_u,TempASub,Proj),
    call_to_success_fact(Sg,Hv,Head,not_provided,Sv,TempASub,Proj,_,Succ). % TODO: add some ClauseKey?
success_builtin(arg,_,_,_,_,'$bottom').
success_builtin(exp,_,Sg,_,Call,Succ):-
    Head = p(A,f(A,_B)),
    varset(Sg,Sv),
    varset(Head,Hv),
    project(Sg,Sv,not_provided_HvFv_u,Call,Proj),
    call_to_success_fact(Sg,Hv,Head,not_provided,Sv,Call,Proj,_,Succ). % TODO: add some ClauseKey?
success_builtin(exp,_,_,_,_,'$bottom').
success_builtin('=../2',_,p(X,Y),_,(Call_SH,Call_fr),Succ):-
    varset(X,Varsx),
    values_equal(Varsx,Call_fr,g),!,
    varset(Y,VarsY),
    update_lambda_cf(VarsY,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('=../2',_,p(X,Y),_,(Call_SH,Call_fr),Succ):-
    varset(Y,VarsY),
    values_equal(VarsY,Call_fr,g),!,
    varset(X,VarsX),
    update_lambda_cf(VarsX,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('=../2',Sv_uns,p(X,Y),_,Call,Succ):-
    var(X), var(Y),!,
    sort(Sv_uns,Sv),
    Call = (_,Call_fr),
    project_freeness(Sv,Call_fr,[A/Val1,B/Val2]),
    ( obtain_freeness(Val1,Val2) ->
        extend(not_provided_Sg,(([],[Sv]),[A/nf,B/nf]),Sv,Call,Succ)
    ; Succ = '$bottom'
    ).
success_builtin('=../2',Sv_uns,p(X,Y),_,Call,Succ):-
    var(X), !,
    sort(Sv_uns,Sv),
    Call = (Call_SH,Call_fr),       
    project_freeness(Sv,Call_fr,Proj_fr),
    Y = [Z|_],
    var_value(Proj_fr,X,ValueX),
    ( var(Z) ->
        var_value(Proj_fr,Z,ValueZ),
        ( ValueZ = f , ValueX = f ->
            Succ = '$bottom'
        ; ord_subtract(Sv,[Z],NewVars),
          sharing_clique:project(not_provided_Sg,NewVars,not_provided_HvFv_u,Call_SH,Proj_SH),
          ord_subtract(NewVars,[X],VarsY),
          product_clique(ValueX,X,VarsY,Sv,Proj_SH,Proj_fr,Prime_SH,Prime_fr),
          extend(not_provided_Sg,(Prime_SH,Prime_fr),Sv,Call,Succ)
        )
    ; sharing_clique:project(not_provided_Sg,Sv,not_provided_HvFv_u,Call_SH,Proj_SH),
      ord_subtract(Sv,[X],VarsY),
      product_clique(ValueX,X,VarsY,Sv,Proj_SH,Proj_fr,Prime_SH,Prime_fr),
      extend(not_provided_Sg,(Prime_SH,Prime_fr),Sv,Call,Succ)
    ).
success_builtin('=../2',Sv_uns,Sg,_,Call,Succ):- Sg=p(X,Y),
    X =.. T,
    sort(Sv_uns,Sv),
    project(Sg,Sv,not_provided_HvFv_u,Call,Proj),
    call_to_success_builtin('=/2','='(T,Y),Sv,Call,Proj,Succ).
success_builtin(recorded,_,Sg,_,Call,Succ):- Sg=p(Y,Z),
    varset(Z,NewG),
    varset(Y,VarsY),
    merge(NewG,VarsY,Vars),
    project(Sg,Vars,not_provided_HvFv_u,Call,(SH,Fr)),
    update_lambda_cf(NewG,Fr,SH,TempPrime_fr,TempPrime_SH),
    make_clique_dependence(TempPrime_SH,VarsY,TempPrime_fr,Prime_fr,Prime_SH),
    Prime = (Prime_SH,Prime_fr),
    extend(Sg,Prime,Vars,Call,Succ).
success_builtin(copy_term,_,Sg,_,Call,Succ):- Sg=p(X,Y),
    varset(X,VarsX),
    project(Sg,VarsX,not_provided_HvFv_u,Call,ProjectedX),
    copy_term((X,ProjectedX),(NewX,NewProjectedX)),
    abs_sort(NewProjectedX,ProjectedNewX),
    varset(NewX,VarsNewX),
    varset(Y,VarsY),
    merge(VarsNewX,VarsY,TempSv),
    project(Sg,VarsY,not_provided_HvFv_u,Call,ProjectedY),
    ProjectedY = (SHY,FrY),
    ProjectedNewX = (SHNewX,FrNewX),
    ord_union_w(SHY,SHNewX,TempSH), 
    merge(FrY,FrNewX,TempFr),
    Call = (SHCall,FrCall),
    ord_union_w(SHNewX,SHCall,TempCallSH),
    merge(FrNewX,FrCall,TempCallFr),
    call_to_success_builtin('=/2','='(NewX,Y),TempSv,
                (TempCallSH,TempCallFr),(TempSH,TempFr),Temp_success),
    collect_vars_freeness(FrCall,VarsCall),
    project(Sg,VarsCall,not_provided_HvFv_u,Temp_success,Succ).
success_builtin('current_key/2',_,p(X),_,Call,Succ):-
    varset(X,NewG),
    Call = (Call_SH,Call_fr),
    update_lambda_cf(NewG,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('current_predicate/2',_,p(X,Y),_,Call,Succ):-
    var(Y),!,
    Call = (Call_SH,Call_fr),
    change_values_if_f([Y],Call_fr,Temp_fr,nf), 
    varset(X,NewG),
    update_lambda_cf(NewG,Temp_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('current_predicate/2',_,p(X,_Y),_,Call,Succ):- !,
    Call = (Call_SH,Call_fr),
    varset(X,NewG),
    update_lambda_cf(NewG,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin(findall,_,p(X,Z),_,(Call_SH,Call_fr),(Succ_SH,Succ_fr)):-
    varset(X,Xs),
    member_value_freeness(Call_fr,GVars,g),
    ord_subset(Xs,GVars), !,
    varset(Z,Zs),
    update_lambda_cf(Zs,Call_fr,Call_SH,Succ_fr,Succ_SH).
success_builtin(findall,_,_,_,Call,Call).
%
success_builtin('functor/3',_,p(X,Y,Z),_,Call,Succ):-
    var(X),
    Call = (Call_SH,Call_fr),
    var_value(Call_fr,X,f),!,
    change_values([X],Call_fr,Temp_fr,nf), 
    varset([Y,Z],OldG),
    ( update_lambda_clique_non_free(OldG,Temp_fr,Call_SH,Succ_fr,Succ_SH) ->
      Succ = (Succ_SH,Succ_fr)
    ; Succ = '$bottom'
    ).
success_builtin('functor/3',_,p(_X,Y,Z),_,Call,Succ):- !,
    Call = (Call_SH,Call_fr),
    varset([Y,Z],NewG),
    update_lambda_cf(NewG,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('name/2',_,p(X,Y),_,Call,Succ):-
    varset(X,OldG),
    Call = (Call_SH,Call_fr),
    update_lambda_clique_non_free(OldG,Call_fr,Call_SH,Temp_fr,Temp_SH),!,
    varset(Y,NewG),
    update_lambda_cf(NewG,Temp_fr,Temp_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('name/2',_,p(X,Y),_,Call,Succ):-
    varset(Y,OldG),
    Call = (Call_SH,Call_fr),
    update_lambda_clique_non_free(OldG,Call_fr,Call_SH,Temp_fr,Temp_SH),!,
    varset(X,NewG),
    update_lambda_cf(NewG,Temp_fr,Temp_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('name/2',_,_,_,_,'$bottom').
success_builtin('nonvar/1',_,p(X),_,Call,Succ):-
    var(X), !,
    Call = (_Call_SH,Call_fr),
    var_value(Call_fr,X,Val),
    ( Val = f ->
      Succ = '$bottom'
    ; Succ = Call
    ).
success_builtin('nonvar/1',_,_,_,Call,Call):- !.
success_builtin('not_free/1',_,p(X),_,Call,Succ):-
    success_builtin('nonvar/1',_,p(X),_,Call,Succ).
success_builtin('numbervars/3',_,p(X,Y,Z),_,Call,Succ):-
    Call = (Call_SH,Call_fr),
    varset(Y,OldG),
    update_lambda_clique_non_free(OldG,Call_fr,Call_SH,Temp_fr,Temp_SH),!,
    varset(p(X,Z),NewG),
    update_lambda_cf(NewG,Temp_fr,Temp_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('numbervars/3',_,_,_,_,'$bottom').
success_builtin('compare/3',_,p(X),_,Call,Succ):- 
    atom(X),!,
    Succ = Call.
success_builtin('compare/3',_,p(X),_,Call,Succ):- 
    var(X),!,
    Call = (Call_SH,Call_fr),
    update_lambda_cf([X],Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
success_builtin('compare/3',_,_,_,_,'$bottom').
success_builtin('indep/2',_,p(X,Y),_,Call,Succ):- 
    ( ground(X) ; ground(Y) ), !,
    Succ = Call.
success_builtin('indep/2',_,p(X,Y),_,Call,Succ):- 
    varset(X,Xv),
    varset(Y,Yv),
    Call = ((Call_Cl,Call_Sh),Call_fr),
    varset(Call_fr,Vars),        
    eliminate_couples_clique(Call_Cl,Xv,Yv,Succ_Cl),
    eliminate_couples(Call_Sh,Xv,Yv,Succ_Sh),
    ord_union(Succ_Cl,Succ_Sh,Succ_SH),
    projected_gvars(Succ_SH,Vars,Ground),
    change_values_if_differ(Ground,Call_fr,Succ_fr,g,f),!,
    Succ = ((Succ_Cl,Succ_Sh),Succ_fr).
success_builtin('indep/2',_,_,_,_,'$bottom').
success_builtin('indep/1',_,p(X),_,Call,Succ):- 
    nonvar(X),
    handle_each_indep(X,sharefree_clique,Call,Succ), !.  
success_builtin('indep/1',_,_,_,_,'$bottom').

success_builtin('var/1',[X],p(X),_,Call,Succ):- 
    Call = (Call_SH,Call_fr),
    var_value(Call_fr,X,Valuex),
    Valuex \== g,
    change_values([X],Call_fr,Succ_fr,f),
    Succ = (Call_SH,Succ_fr), !.
success_builtin('var/1',_,_,_,_,'$bottom').
success_builtin('free/1',[V],p(V),HvFv_u,Call,Succ):- !,
    success_builtin('var/1',[V],p(V),HvFv_u,Call,Succ).

:- pred call_to_success_builtin(+SgKey,+Sg,+Sv,+Call,+Proj,-Succ)
   # "Handles those builtins for which computing `Prime` is easier than `Succ`.".

:- dom_impl(_, call_to_success_builtin/6, [noq]).
call_to_success_builtin('=/2','='(X,_Y),Sv,Call,(_,Proj_fr),Succ):-
    varset(X,VarsX), values_equal(VarsX,Proj_fr,g), !,
    Call = (Call_SH,Call_fr),
    ord_subtract(Sv,VarsX,VarsY),
    update_lambda_cf(VarsY,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
call_to_success_builtin('=/2','='(_X,Y),Sv,Call,(_,Proj_fr),Succ):-
    varset(Y,VarsY), values_equal(VarsY,Proj_fr,g), !,
    Call = (Call_SH,Call_fr),
    ord_subtract(Sv,VarsY,VarsX),
    update_lambda_cf(VarsX,Call_fr,Call_SH,Succ_fr,Succ_SH),
    Succ = (Succ_SH,Succ_fr).
call_to_success_builtin('=/2','='(X,Y),Sv,Call,Proj,Succ):-
    var(X),var(Y), !,
    Proj = (_,Proj0_fr),    
    project_freeness(Sv,Proj0_fr,Proj_fr),  %% necessary for def
    obtain_prime_clique_var_var(Proj_fr,Call,Succ).
call_to_success_builtin('=/2','='(X,_Y),Sv,Call,Proj,Succ):-
    var(X), !,
    Proj = (Proj_SH,Proj_fr),       
    ord_subtract(Sv,[X],VarsY),
    var_value(Proj_fr,X,ValueX),
    product_clique(ValueX,X,VarsY,Sv,Proj_SH,Proj_fr,Prime_SH,Prime_fr),
    Prime= (Prime_SH,Prime_fr),
    extend(not_provided_Sg,Prime,Sv,Call,Succ).
call_to_success_builtin('=/2','='(X,Y),Sv,Call,Proj,Succ):-
    copy_term(X,Xterm),
    copy_term(Y,Yterm),
    Xterm = Yterm,!,
    varset(Xterm,Vars),
    call_to_success_fact('='(X,Y),Vars,'='(Xterm,Xterm),not_provided,Sv,Call,Proj,_Prime,Succ). % TODO: add some ClauseKey?
call_to_success_builtin('=/2',_Sg,_Sv,_Call,_Proj,'$bottom'):-!.
call_to_success_builtin('C/3','C'(X,Y,Z),Sv,Call,Proj,Succ):-
    call_to_success_fact('='(X,[Y|Z]),[W],'='(W,W),not_provided,Sv,Call,Proj,_Prime,Succ). % TODO: add some ClauseKey?
call_to_success_builtin('sort/2',sort(X,Y),Sv,Call,Proj,Succ):- 
    var(X), !,
    Proj = (_SH,Fr),
    var_value(Fr,X,Val),
    ( Val = f ->
      Succ = '$bottom'
    ; varset([X,Y],Sv),
      copy_term(Y,Yterm),
      varset(Yterm,Vars),
      call_to_success_fact('='(X,Y),Vars,'='(Yterm,Yterm),not_provided,Sv,Call,Proj,_Prime,Succ) % TODO: add some ClauseKey?
    ).
call_to_success_builtin('sort/2',sort(X,Y),Sv,Call,Proj,Succ):- 
    functor(X,'.',_), !,
    varset0(X,[Z|_]),
    Call = (Call_SH,Call_fr),
    change_values_if_f([Z],Call_fr,Temp_fr,nf),
    varset([X,Y],Sv),
    copy_term(X,Xterm),
    copy_term(Y,Yterm),
    Xterm = Yterm,
    varset(Xterm,Vars),
    Proj = (SH,Fr),
    change_values_if_f([Z],Fr,TFr,nf),
    call_to_success_fact('='(X,Y),Vars,'='(Xterm,Xterm),not_provided,Sv,(Call_SH,Temp_fr),(SH,TFr),_Prime,Succ). % TODO: add some ClauseKey? 
call_to_success_builtin('keysort/2',keysort(X,Y),Sv,Call,Proj,Succ):- 
    call_to_success_builtin('=/2','='(X,Y),Sv,Call,Proj,Succ).

%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
%                      Intermediate operations                           %
%------------------------------------------------------------------------%
%------------------------------------------------------------------------%
% Most of the following operations are defined in sharefree.pl           | 
% They should be exported by share.pl (they are defined in sharefree.pl) |
%------------------------------------------------------------------------%

:- use_module(domain(sharefree), [
    add_environment_vars/3,
    change_values/4,
    change_values_if_f/4,
    member_value_freeness_differ/3,
    obtain_freeness/2, % TODO:!! old comment, why? (JF)
    project_freeness/3,
    propagate_non_freeness/5,
    values_equal/3
   ]).

:- pred update_lambda_clique_non_free(+Gv,+Fr,+Sh,-NewFr,-NewSh)
   #
"Identical to `update_lambda_sf` but:                                    
-  it tests that the variables that become ground are not free.        
   The reason is that `Ground` should be ground already, and therefore   
   they cannot make a definitely free variable to become ground.        
-  it does not change the freeness value of any variable from `f` to `nf`  
   (The same reason).                                                     
".
update_lambda_clique_non_free([],Fr,Sh,Fr,Sh).
update_lambda_clique_non_free([X|Xs],Fr,SH,Fr1,SH1):-
    rel_w([X|Xs],SH,(Int_Cl,Int_Sh)),
    irrel_w([X|Xs],SH,(Disj_Cl,Disj_Sh)),
    ord_union(Int_Cl,Int_Sh,Int),
    ord_union(Disj_Cl,Disj_Sh,Disj),
    merge_list_of_lists(Int,Coupled),
    merge_list_of_lists(Disj,NotCoupled),
    ord_subtract(Coupled,NotCoupled,NewGv),
    change_values_if_differ(NewGv,Fr,Fr1,g,f),
    SH1= (Cl1,Disj_Sh),
    delete_vars_from_list_of_lists([X|Xs],Int_Cl,Cl2),
    sort_list_of_lists(Cl2,Cl2_sorted),
    ord_union(Cl2_sorted,Disj_Cl,Cl1).
    
:- pred update_lambda_cf(+Gv,+Fr,+Sh,-NewFr,-NewSh)
   #
"This predicates handles the case in which a set of variables (`Gv`) have 
been determined as ground, and it has to:                              
- Update the sharing&clique component.                                
- Update the freeness component in order to:                         
  - all ground variables appear as ground.                        
  - those free variables which are coupled (but not are become   
    ground) should become non free.                              
".

update_lambda_cf([],Fr,Sh,Fr,Sh):- !.
update_lambda_cf(Gv,Fr,SH,Fr1,SH1):-
    rel_w(Gv,SH,(Int_Cl,Int_Sh)),
    irrel_w(Gv,SH,(Disj_Cl,Disj_Sh)),
    ord_union(Int_Cl,Int_Sh,Int),
    ord_union(Disj_Cl,Disj_Sh,Disj),
    merge_list_of_lists(Int,Coupled),
    merge_list_of_lists(Disj,NotCoupled),
    ord_intersection_diff(Coupled,NotCoupled,NonFv,NewGv),
    change_values(NewGv,Fr,Temp_Fr,g),
    change_values_if_f(NonFv,Temp_Fr,Fr1,nf),
    SH1= (Cl1,Disj_Sh),
    delete_vars_from_list_of_lists(Gv,Int_Cl,Cl2),
    sort_list_of_lists(Cl2,Cl2_sorted),
    ord_union(Cl2_sorted,Disj_Cl,Cl1).

%% %-------------------------------------------------------------------------
%% % mynonvar(+,+,+)                                                        |
%% % mynonvar(Vars,Fr,Fv)                                                   |
%% % Satisfied if the variables in Vars are definitely nonvariables         |
%% %-------------------------------------------------------------------------
%% 
%% mynonvar([],_Sh,_Free).
%% mynonvar([F|Rest],Sh,Free):-
%%      insert(Free,F,Vars),
%%      share_project(not_provided_Sg,Vars,not_provided_HvFv_u,Sh,NewSh),
%%      impossible(NewSh,NewSh,Vars),!,
%%      mynonvar(Rest,Sh,Free).

:- pred non_free_vars(+Vars,+Fr1,+Fr2,-Fv,-NewFr)
   #
"`NewFr` is the result of adding to `Fr2` all `X`/`nf` s.t. `X` in `Vars` and `X`/`nf`  
in `Fr1` (Note that if `X` in `Vars`, then `X`/_ not in `Fr2`).                  
`Fv` contains the rest of variables in `Vars`. All ordered.                 
The reason is the following: `Vars` is the set of variables in success   
and not in prime. Thus, those variables in `Vars` with value in `Call`     
different from `nf` are free, and should be added to `BVarsf`.             
".

:- push_prolog_flag(multi_arity_warnings,off).
% TODO: change names for different arities?
non_free_vars([],_,Fr2,[],Fr2).
non_free_vars([X|Xs],Fr1,Fr2,BVarsf,NewFr):-
    non_free_vars(Fr2,X,Xs,Fr1,BVarsf,NewFr).

non_free_vars([],X,Xs,[Y/V|Fr1],BVarsf,NewFr):-
    compare(D,X,Y),
    non_free_vars1(D,X,Xs,V,Fr1,BVarsf,NewFr).
non_free_vars([Y/V|Fr2],X,Xs,Fr1,BVarsf,NewFr):-
    compare(D,X,Y),
    non_free_vars(D,X,Xs,Fr1,Y/V,Fr2,BVarsf,NewFr).

non_free_vars(>,X,Xs,Fr1,Elem,Fr2,BVarsf,[Elem|NewFr]):-
    non_free_vars(Fr2,X,Xs,Fr1,BVarsf,NewFr).
non_free_vars(<,X,Xs,Fr1,Elem,Fr2,BVarsf,NewFr):-
    var_value_rest(Fr1,X,nf,New_Fr1,Flag),
    non_free_vars(Flag,X,Xs,New_Fr1,[Elem|Fr2],BVarsf,NewFr).

non_free_vars1(>,X,Xs,_,[Y/V|Fr1],BVarsf,NewFr):-
    compare(D,X,Y),
    non_free_vars1(D,X,Xs,V,Fr1,BVarsf,NewFr).
non_free_vars1(=,X,Xs,V,Fr1,BVarsf,NewFr):-
    V = nf,!,
    NewFr = [X/nf|Rest_temp2],
    non_free_vars2(Xs,Fr1,BVarsf,Rest_temp2).
non_free_vars1(=,X,Xs,_V,Fr1,[X|BVarsf],NewFr):-
    non_free_vars2(Xs,Fr1,BVarsf,NewFr).

non_free_vars2([],_Fr1,[],[]).
non_free_vars2([X|Xs],[Y/V|Fr1],BVarsf,NewFr):-
    compare(D,X,Y),
    non_free_vars1(D,X,Xs,V,Fr1,BVarsf,NewFr).

non_free_vars(yes,X,Xs,Fr1,Fr2,BVarsf,[X/nf|NewFr]):-
    non_free_vars(Xs,Fr1,Fr2,BVarsf,NewFr).
non_free_vars(no,X,Xs,Fr1,Fr2,[X|BVarsf],NewFr):-
    non_free_vars(Xs,Fr1,Fr2,BVarsf,NewFr).

:- pop_prolog_flag(multi_arity_warnings).

:- pred var_value_rest(+Fr,in_var(X),+Value,-NewFr,-Flag)
   #
"If the freeness value of `X` in `Fr` is `Value`, then `Flag` = yes.            
Otherwise it is set to no.                                             
`NewFr` is the result of eliminating all `Y`/`V` s.t. `Y` less equal `X`.        
".

:- push_prolog_flag(multi_arity_warnings,off).

var_value_rest([],_X,_Value,no,[]).
var_value_rest([Y/V|More],X,Value,Rest,Flag):-
    compare(D,X,Y),
    var_value_rest(D,V,More,X,Value,Rest,Flag).

var_value_rest(=,V,More,_X,Value,Rest,Flag):-
    V = Value,!,
    Flag = yes,
    Rest = More.
var_value_rest(=,_V,More,_X,_Value,Rest,Flag):-
    Flag = no,
    Rest = More.
var_value_rest(>,_Elem,More,X,Value,Rest,Flag):-
    var_value_rest(More,X,Value,Rest,Flag).

:- pop_prolog_flag(multi_arity_warnings).

:- pred make_clique_dependence(+Sh,+Vars,+Fr,-NewFr,-NewSh)
   #
"It gives the new sharing and freeness component for the variables in `Y` 
(`Vars`) when `recorded(X,Y,Z)` was called, once the variables in `Z` have   
been made ground.                                                      
".

make_clique_dependence(([],[]),Y,TempPrime_fr,Prime_fr,([],[])):- !,
    change_values(Y,TempPrime_fr,Prime_fr,g).
make_clique_dependence(SH,Y,TempPrime_fr,Prime_fr,Prime_SH):- 
    star_w(SH,Prime_SH),
    change_values_if_f(Y,TempPrime_fr,Prime_fr,nf).

:- pred propagate_clique_non_freeness(+Vars,+NonFv,+Sh,+Fr,-NewFr).

propagate_clique_non_freeness([],_,_,Fr,Fr) :- !.
propagate_clique_non_freeness(Vars,NonFv,(Cl,Sh),Fr,NewFr):-
      propagate_non_freeness(Vars,NonFv,Cl,Fr,NewFr1),
      propagate_non_freeness(Vars,NonFv,Sh,Fr,NewFr2),
      compute_lub_fr(NewFr1,NewFr2,NewFr).

product_clique(f,X,VarsY,_,SH,Lda_fr,Prime_SH,Prime_fr):-
    sharing_clique:project(not_provided_Sg,VarsY,not_provided_HvFv_u,SH,Temp),
    bin_union_w(Temp,([],[[X]]),Temp1),
    sharing_clique:abs_sort(Temp1,Prime_SH),
    take_clique_coupled(SH,[X],Coupled),
    change_values_if_f(Coupled,Lda_fr,Prime_fr,nf).
product_clique(nf,X,VarsY,Sv,SH,Lda_fr,Prime_SH,Prime_fr):-
    sharing_clique:project(not_provided_Sg,VarsY,not_provided_HvFv_u,SH,Temp),
    star_w(Temp,Temp1),
    bin_union_w(Temp1,([],[[X]]),Temp2),
    sharing_clique:abs_sort(Temp2,Prime_SH),
    take_clique_coupled(SH,Sv,Coupled),
    change_values_if_f(Coupled,Lda_fr,Prime_fr,nf).

:- pred take_clique_coupled(+Sh,+Vars,-Coupled)
   #
"`Sh` is pair of list of lists of variables, `Vars` is a list of variables.  
Returns in `Coupled` the list of variables `X` s.t. exists at least        
one list in `Sh` containing `X` and at least one element in `Vars`.          
".

take_clique_coupled((Cl,Sh),Vars_u,Coupled):-
    sort(Vars_u,Vars),
%% sharing
    ord_split_lists_from_list(Vars,Sh,Intersect_Sh,_),
    merge_list_of_lists(Intersect_Sh,IntVars_Sh),
    merge(Vars,IntVars_Sh,Coupled_Sh),
%% clique
    ord_split_lists_from_list(Vars,Cl,Intersect_Cl,_),
    merge_list_of_lists(Intersect_Cl,IntVars_Cl),
    merge(Coupled_Sh,IntVars_Cl,Coupled).

:- pred obtain_prime_clique_var_var(+[X/V,Y/V],+Call,-Success)
   #
"Handles the case `X` = `Y` where both `X`,`Y` are variables which freeness     
value \== `g`.                                                            
".

obtain_prime_clique_var_var([X/f,Y/f],(Call_SH,Call_fr),Succ):- !,
    amgu_clique_ff(X,[Y],Call_SH,Succ_SH),
    Succ = (Succ_SH,Call_fr).
obtain_prime_clique_var_var([X/_,Y/_],Call,Succ):-
    Prime = (([],[[X,Y]]),[X/nf,Y/nf]),
    extend(not_provided_Sg,Prime,[X,Y],Call,Succ).

