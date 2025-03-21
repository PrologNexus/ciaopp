:- module(shfret,
    [ shfret_init_abstract_domain/1,
      shfret_call_to_entry/9,
      shfret_exit_to_prime/7,
      shfret_project/5,
      shfret_extend/5,
      shfret_widen/3,
      shfret_widencall/3,
      shfret_compute_lub/2,
      shfret_glb/3,
      shfret_eliminate_equivalent/2,
      shfret_less_or_equal/2,
      shfret_identical_abstract/2,
      shfret_abs_sort/2,
      shfret_call_to_success_fact/9,
      shfret_combined_special_builtin0/2,
      shfret_split_combined_domain/3,
      shfret_input_interface/4,
      shfret_input_user_interface/5,
      shfret_asub_to_native/5,
      shfret_unknown_call/4,
      shfret_unknown_entry/3,
      shfret_empty_entry/3
    ],
    [ assertions,regtypes,modes_extra
    ]).

:- doc(title, "shfret: sharing+freeness+regtypes (abstract domain)").
:- doc(stability, alpha).

:- include(ciaopp(plai/plai_domain)).
:- dom_def(shfret).
:- dom_impl(shfret, init_abstract_domain/1).
:- dom_impl(shfret, call_to_entry/9).
:- dom_impl(shfret, exit_to_prime/7).
:- dom_impl(shfret, project/5).
:- dom_impl(shfret, widencall/3).
:- dom_impl(shfret, needs/1).
:- dom_impl(shfret, widen/3).
:- dom_impl(shfret, compute_lub/2).
:- dom_impl(shfret, identical_abstract/2).
:- dom_impl(shfret, abs_sort/2).
:- dom_impl(shfret, extend/5).
:- dom_impl(shfret, less_or_equal/2).
:- dom_impl(shfret, glb/3).
:- dom_impl(shfret, eliminate_equivalent/2).
:- dom_impl(shfret, call_to_success_fact/9).
:- dom_impl(shfret, combined_special_builtin0/2).
:- dom_impl(shfret, split_combined_domain/3).
:- dom_impl(shfret, input_interface/4).
:- dom_impl(shfret, input_user_interface/5).
:- dom_impl(shfret, asub_to_native/5).
:- dom_impl(shfret, unknown_call/4).
:- dom_impl(shfret, unknown_entry/3).
:- dom_impl(shfret, empty_entry/3).

:- use_module(domain(eterms)).
:- use_module(domain(sharefree), [
    call_to_entry/9,
    exit_to_prime/7,
    project/5,
    extend/5,
    needs/1,
    compute_lub/2,
    glb/3,
    less_or_equal/2,
    abs_sort/2,
    call_to_success_fact/9,
    input_interface/4,
    input_user_interface/5,
    asub_to_native/5,
    unknown_call/4,
    unknown_entry/3,
    empty_entry/3
]).

% infers(ground/1, rtcheck).
% inters(var/1, rtcheck).
% infers(mshare/1, rtcheck).
% infers(regtypes, rtcheck).

%% :- use_module(library(idlists),[memberchk/2]).
:- use_module(library(lists), [append/3]).
%% :- use_module(library(sets),[ord_subtract/3]).
%% :- use_module(library(sort),[sort/2]).

asub(comb(Types,Modes),Types,Modes).

% ---------------------------------------------------------------------------

:- use_module(ciaopp(preprocess_flags), [push_pp_flag/2]).

shfret_init_abstract_domain([variants,widen]) :-
    push_pp_flag(variants,off),
    push_pp_flag(widen,on).

:- pred shfret_call_to_entry(+Sv,+Sg,+Hv,+Head,+K,+Fv,+Proj,-Entry,-ExtraInfo).
 
shfret_call_to_entry(Sv,Sg,Hv,Head,K,Fv,Proj,Entry,ExtraInfo):-
    asub(Proj,PTypes,PModes),
    sharefree:call_to_entry(Sv,Sg,Hv,Head,K,Fv,PModes,EModes,ExtraInfoModes),
    eterms_call_to_entry(Sv,Sg,Hv,Head,K,Fv,PTypes,ETypes,ExtraInfoTypes),
    ( ETypes = '$bottom' ->
        Entry = '$bottom'
    ; asub(Entry,ETypes,EModes)
    ),
    asub(ExtraInfo,ExtraInfoTypes,ExtraInfoModes).

:- pred shfret_exit_to_prime(+Sg,+Hv,+Head,+Sv,+Exit,-ExtraInfo,-Prime).

shfret_exit_to_prime(_Sg,_Hv,_Head,_Sv,'$bottom',_ExtraInfo,'$bottom'):- !.
shfret_exit_to_prime(Sg,Hv,Head,Sv,Exit,ExtraInfo,Prime):-
    asub(Exit,ETypes,EModes),
    asub(ExtraInfo,ExtraInfoTypes,ExtraInfoModes),
    sharefree:exit_to_prime(Sg,Hv,Head,Sv,EModes,ExtraInfoModes,PModes),
    eterms_exit_to_prime(Sg,Hv,Head,Sv,ETypes,ExtraInfoTypes,PTypes),
    ( PTypes = '$bottom' ->
        Prime = '$bottom'
     ; asub(Prime,PTypes,PModes)
    ).

:- pred shfret_project(+Sg,+Vars,+HvFv_u,+ASub,-Proj).

shfret_project(_Sg,_Vars,_HvFv_u,'$bottom','$bottom'):- !.
shfret_project(Sg,Vars,HvFv_u,ASub,Proj):-
    asub(ASub,ATypes,AModes),
    sharefree:project(Sg,Vars,HvFv_u,AModes,PModes),
    eterms_project(Sg,Vars,HvFv_u,ATypes,PTypes),
    asub(Proj,PTypes,PModes).

:- pred shfret_extend(+Sg,+Prime,+Sv,+Call,-Succ).

shfret_extend(_Sg,'$bottom',_Sv,_Call,'$bottom'):- !.
shfret_extend(Sg,Prime,Sv,Call,Succ):-
    asub(Prime,PTypes,PModes),
    asub(Call,CTypes,CModes),
    sharefree:extend(Sg,PModes,Sv,CModes,SModes),
    eterms_extend(Sg,PTypes,Sv,CTypes,STypes),
    asub(Succ,STypes,SModes).


shfret_needs(widen) :- !.
shfret_needs(split_combined_domain) :- !.
shfret_needs(X) :-
    eterms_needs(X), !.
shfret_needs(X) :-
    sharefree:needs(X).

:- pred shfret_widen(+ASub1,+ASub2,-ASub).

shfret_widen('$bottom',ASub1,ASub):- !, ASub=ASub1.
shfret_widen(ASub0,'$bottom',ASub):- !, ASub=ASub0.
shfret_widen(ASub0,ASub1,ASub):-
    asub(ASub0,ATypes0,AModes0),
    asub(ASub1,ATypes1,AModes1),
    sharefree:compute_lub([AModes0,AModes1],AModes),
    eterms_widen(ATypes0,ATypes1,ATypes),
    asub(ASub,ATypes,AModes).

:- pred shfret_widencall(+ASub1,+ASub2,-ASub).

shfret_widencall('$bottom',ASub1,ASub):- !, ASub=ASub1.
shfret_widencall(ASub0,'$bottom',ASub):- !, ASub=ASub0.
shfret_widencall(ASub0,ASub1,ASub):-
    asub(ASub0,ATypes0,_AModes0),
    asub(ASub1,ATypes1,AModes1),
    eterms_widencall(ATypes0,ATypes1,ATypes),
    asub(ASub,ATypes,AModes1).

:- pred shfret_compute_lub(+ListASub,-Lub).

shfret_compute_lub(ListASub,Lub):-
    split(ListASub,LTypes,LModes),
    sharefree:compute_lub(LModes,LubModes),
    eterms_compute_lub(LTypes,LubTypes),
    asub(Lub,LubTypes,LubModes).

split([],[],[]).
split([ASub|ListASub],LTypes,LModes):- ASub == '$bottom', !,
    split(ListASub,LTypes,LModes).
split([ASub|ListASub],[ATypes|LTypes],[AModes|LModes]):-
    asub(ASub,ATypes,AModes),
    split(ListASub,LTypes,LModes).

shfret_split_combined_domain(ListASub,[LTypes,LModes],[eterms,shfr]):-
    split(ListASub,LTypes,LModes).

:- pred shfret_glb(+ASub0,+ASub1,-Glb).

shfret_glb('$bottom',_ASub,ASub3) :- !, ASub3='$bottom'.
shfret_glb(_ASub,'$bottom',ASub3) :- !, ASub3='$bottom'.
shfret_glb(ASub0,ASub1,Glb):-
    asub(ASub0,ATypes0,AModes0),
    asub(ASub1,ATypes1,AModes1),
    sharefree:glb(AModes0,AModes1,GModes),
    eterms_glb(ATypes0,ATypes1,GTypes),
    asub(Glb,GTypes,GModes).

%------------------------------------------------------------------------%

shfret_eliminate_equivalent(LSucc,LSucc). % TODO: wrong or not needed? (JF)

:- pred shfret_less_or_equal(+ASub0,+ASub1).

shfret_less_or_equal('$bottom','$bottom'):- !.
shfret_less_or_equal(ASub0,ASub1):-
    asub(ASub0,ATypes0,AModes0),
    asub(ASub1,ATypes1,AModes1),
    sharefree:less_or_equal(AModes0,AModes1),
    eterms_less_or_equal(ATypes0,ATypes1).

:- pred shfret_identical_abstract(+ASub1,+ASub2).

shfret_identical_abstract('$bottom','$bottom'):- !.
shfret_identical_abstract(ASub0,ASub1):-
    asub(ASub0,ATypes0,AModes0),
    asub(ASub1,ATypes1,AModes1),
    AModes0 == AModes1,
    eterms_identical_abstract(ATypes0,ATypes1).

:- pred shfret_abs_sort(+ASub0,-ASub1).

shfret_abs_sort('$bottom','$bottom'):- !.
shfret_abs_sort(ASub0,ASub1):-
    asub(ASub0,ATypes0,AModes0),
    sharefree:abs_sort(AModes0,AModes1),
    eterms_abs_sort(ATypes0,ATypes1),
    asub(ASub1,ATypes1,AModes1).

:- pred shfret_call_to_success_fact(+Sg,+Hv,+Head,+K,+Sv,+Call,+Proj,-Prime,-Succ).

shfret_call_to_success_fact(Sg,Hv,Head,K,Sv,Call,Proj,Prime,Succ):-
    asub(Call,CTypes,CModes),
    asub(Proj,PTypes,PModes),
    sharefree:call_to_success_fact(Sg,Hv,Head,K,Sv,CModes,PModes,RModes,SModes),
    eterms_call_to_success_fact(Sg,Hv,Head,K,Sv,CTypes,PTypes,RTypes,STypes),
    asub(Prime,RTypes,RModes),
    asub(Succ,STypes,SModes).

% ---------------------------------------------------------------------------

:- use_module(ciaopp(plai/domains), [special_builtin/6, body_builtin/9]).

% TODO: [DF] special_builtin requires Sg to be instantiated
shfret_combined_special_builtin0(SgKey,Domains) :-
    % TODO: refactor (define a nondet pred with combined domains instead)
    ( special_builtin(eterms,SgKey, not_provided_Sg,SgKey,_Type,_Condvars) ->
        Domains=[eterms,shfr]
    ; special_builtin(shfr,SgKey, not_provided_Sg,SgKey,_Type,_Condvars) ->
        Domains=[eterms,shfr]
    ; fail
    ).

:- pred shfret_input_interface(+InputUser,?Kind,?StructI,?StructO).

shfret_input_interface(InputUser,Kind,StructI,StructO):-
    ( nonvar(Kind) ->
        KModes=Kind, KTypes=Kind
    ; true ),
    asub(StructI,ITypes,IModes),
    shfr_input_interface_(InputUser,KModes,IModes,OModes),
    eterms_input_interface_(InputUser,KTypes,ITypes,OTypes),
    asub(StructO,OTypes,OModes).

shfr_input_interface_(InputUser,Kind,IModes,OModes):-
    sharefree:input_interface(InputUser,Kind,IModes,OModes), !.
shfr_input_interface_(_InputUser,_Kind,IModes,IModes).

eterms_input_interface_(InputUser,Kind,ITypes,OTypes):-
    eterms_input_interface(InputUser,Kind,ITypes,OTypes), !.
eterms_input_interface_(_InputUser,_Kind,ITypes,ITypes).

:- pred shfret_input_user_interface(?InputUser,+Qv,-ASub,+Sg,+MaybeCallASub).

shfret_input_user_interface(Struct,Qv,ASub,Sg,MaybeCallASub):-
    asub(Struct,Types,Modes),
    sharefree:input_user_interface(Modes,Qv,AModes,Sg,MaybeCallASub),
    eterms_input_user_interface(Types,Qv,ATypes,Sg,MaybeCallASub),
    asub(ASub,ATypes,AModes).

:- pred shfret_asub_to_native(+ASub,+Qv,+OutFlag,-Props,-Comps).

shfret_asub_to_native(ASub,Qv,OutFlag,Props,Comps):-
    asub(ASub,ATypes,AModes),
    sharefree:asub_to_native(AModes,Qv,OutFlag,Props1,Comps1),
    eterms_asub_to_native(ATypes,Qv,OutFlag,Props2,Comps2),
    append(Props1,Props2,Props),
    append(Comps1,Comps2,Comps).

:- pred shfret_unknown_call(+Sg,+Vars,+Call,-Succ).
   
shfret_unknown_call(Sg,Vars,Call,Succ):-
    asub(Call,CTypes,CModes),
    sharefree:unknown_call(Sg,Vars,CModes,SModes),
    eterms_unknown_call(Sg,Vars,CTypes,STypes),
    asub(Succ,STypes,SModes).

:- pred shfret_unknown_entry(+Sg,+Vars,-Entry).

shfret_unknown_entry(Sg,Vars,Entry):-
    sharefree:unknown_entry(Sg,Vars,EModes),
    eterms_unknown_entry(Sg,Vars,ETypes),
    asub(Entry,ETypes,EModes).

:- pred shfret_empty_entry(+Sg,+Vars,-Entry).

shfret_empty_entry(Sg,Vars,Entry):-
    sharefree:empty_entry(Sg,Vars,EModes),
    eterms_empty_entry(Sg,Vars,ETypes),
    asub(Entry,ETypes,EModes).
