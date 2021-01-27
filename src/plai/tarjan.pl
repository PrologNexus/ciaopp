:- module(tarjan,[tarjan/2,recursive_classify/4,fake_recursive_classify/2,
              recursive_class/2,step2/2],
             [assertions, datafacts]).

:- doc(stability, alpha).

:- doc(module,"This module performs the syntactic SCC computation of the
program. It also annotates each literal with information about recursivity, meta
calls, and, optionally, generates entries automatically for the meta calls.").

:- use_module(library(sets), [insert/3, merge/3]).
:- use_module(library(lists), [member/2, intersection/3, append/3]).
:- use_module(library(sort), [sort/2]).

:- use_module(ciaopp(p_unit), [type_of_goal/2]).
:- use_module(ciaopp(plai/psets), [ord_remove/3]).

:- use_module(ciaopp(preprocess_flags), [current_pp_flag/2]).

%-------------------------------------------------------------------------
% tarjan(+,-)
% tarjan(Program,Sccs)
% It determines for each predicate if it is or is not recursive
%-------------------------------------------------------------------------
% From: john@compsci.bristol.ac.uk
% Subject: dependency graphs
% Algorithm to find the strongly connected components of a directed graph
% Taken from "Graph Algorithms" by Shimon Even, Pitman (1979), page 65.
%
% The algorithm has complexity k1.E + k2.V + k3 where E is number
% of edges and V is number of vertices (see R. Tarjan:  SIAM J. Computing;
% Vol 1. No 2. p. 146-160).
%
% (Note: the complexity of this version may be a bit worse because it uses
% some less efficient data structures).
%
% The graph is given by the dependency relation of a logic program.
% I.e. the vertices are predicate names and there is an edge p-q if 
% q occurs in the body of a clause with head p.
%
% JPG: 16.9.93   please report bugs etc to john@compsci.bristol.ac.uk
%
% strong_connected_components(Ps,Cs):   
% strong_connected_components(+,-):
%       Ps:  a list of vertices (the edges are generated by procedure step1/2).
%       Cs:  a list of components, each labelled as recursive or non-recursive
%
% Description of data structures (see above references for more details):
%
% vertex(V,Es,K,L,F):   V a vertex (functor/arity)
%                       Es is list of vertices U such that V-U is an edge
%                       K is the number of V
%                       L is the lowpoint of V (see algorithm description)
%                       F is either "undef" or the node by which V was reached.
%
% state(G,V,S,I):       G is the current graph 
%                       V the current vertex
%                       S the stack of visited vertices
%                       I the counter
%
%-------------------------------------------------------------------------
% modified by German Puebla Sanchez as follows (Nov-4-93):
%   - it can be used with meta-calls
%   - it does not fail if it encounters a predicate not defined
%   - receives the program as a list of clauses
%   - it accepts parallel expresions (&)
%   - the information is post-processed to know if each clause is recursive
%   - the output program is in the format:
%         clause(Head,Body,REC)    
%       where REC can either be nr(non-recursive)  or r (recursive) 
%       and N is the order of the recursive clause in the predicate).
%-------------------------------------------------------------------------
% modified by F. Bueno as follows (Jan-14-02):
%   - correct treatment of meta-calls
%   - parallel expresions (&) are just meta-calls
%   - there is no output program, it outputs info on recursiveness
%-------------------------------------------------------------------------

:- export(recursive_classes/1).
:- data recursive_classes/1.
%-------------------------------------------------------------------------

:- compilation_fact(tarjan_list).

:- if(defined(tarjan_list)).
tarjan(Program,(Calls,RC)):-
    retractall_fact(recursive_classes(_)),
    program_pred(Program,Calls,[],P),
    strong_connected_components(Program,Calls,P,RC,_Vertexes),
    asserta_fact(recursive_classes(RC)).
:- else.
:- use_module(ciaopp(plai/program_tarjan)).
% imperative tarjan
tarjan(Program,_):-
    program_tarjan(Program). % TODO: entries not supported in this implementation

:- endif.

%-------------------------------------------------------------------------
:- export(program_pred/4).
% program_pred(+,-,+,-)
% program_pred(Clauses,Calls,[],Ps)
% It returns in Ps the set of functor/arity of all heads in the program
% and in Calls the set of user predicates called by each clause 
%-------------------------------------------------------------------------

program_pred([],[],Ps,Ps).
program_pred([Cl:_|Rest],[C|Calls],TempPs,Ps):-
    clause_pred(Cl,C,TempPs,Ps0),
    program_pred(Rest,Calls,Ps0,Ps).

clause_pred(directive(_),[],Ps,Ps).
clause_pred(clause(H,B),C,TempPs,Ps1):-
    functor(H,N,A),
    insert(TempPs,N/A,Ps1),
    get_module_from_sg(H,M),
    bodylits(B,M,[],U_C),
    sort(U_C,C).

bodylits((B,Bs),M,S,S2):- !,
    bodylits(B,M,S,S1),
    bodylits(Bs,M,S1,S2).
bodylits(G:_,M,S,S1):-
    type_of_goal(metapred(Type,Meta),G), !,
    % TODO: we do not distinguish between primitive_meta_predicate and meta_predicate
    functor(G,T,A),
    create_entries(G,Type,Meta,M),
    S1 = [T/A|S2],
    meta_calls(G,A,M,S,S2).
% TODO: not the optimal solution, working on a better one (IG)
bodylits(G:_,_M,S,S1):-
    type_of_goal(impl_defined,G), !,
    S1 = S.
bodylits(G:_,_M,S,S1):-
    type_of_goal(wam_builtin,G), !,
    S1 = S.
bodylits(G:_,_M,S,[T/N|S]):-
    functor(G,T,N).
bodylits(!,_,S,S).
bodylits(true,_,S,S).

meta_calls(_G,0,_M,S,S) :- !.
meta_calls(G,A,M,S,S2):-
    A > 0,
    arg(A,G,GA),
    ( nonvar(GA),
      GA='$'(Term,Body,goal)
    -> ( var(Term) -> S1 = S
       ; bodylits(Body,M,S,S1) )
     ; S1 = S ),
    A1 is A-1,
    meta_calls(G,A1,M,S1,S2).

%-------------------------------------------------------------------------
% strong_connected_components(+,+,+,-,-) 
% strong_connected_components(Prog,Calls,Ps,Cs,Vertexes) 
% Prog is the set of program clauses and  Ps is the set of 
% functor/arity (P/N) corresponding to all program heads. It first obtains 
% (step1) in [V|Vs] the set of vertex(P/N,Es,0,0,undef) (one for each P/N 
% in Ps) where Es is the set of functor/arity elements corresponding to each 
% literal in some clause belonging to the definition of the predicate P/N,
% and unifies S0 with the initial state: state([V|Vs],V,[],0).
% Then (step2)  ???/
%-------------------------------------------------------------------------

strong_connected_components(_,[],[],[],[]) :- !.
strong_connected_components(Prog,Calls,Ps,Cs,Vertexes) :-
    init_cls(Ps,Empties),
    user_clauses(Prog,Calls,Ps,Empties,Edges),
    init_depends(Ps,Vertexes,Edges),
    ( Vertexes == [] ->
        Cs = []
    ;
        Vertexes = [V|Vs],
        S0 = state([V|Vs],V,[],0),
        step2(S0,Cs)
    ).

:- export(init_cls/2).
init_cls([],[]).
init_cls([_|Preds],[[]|Empties]):-
    init_cls(Preds,Empties).

%-------------------------------------------------------------------------
:- export(init_depends/3).
% init_depends(+,-,+)
% init_depends(Preds,Vertexes,Edges) 
% Preds is the set of functor/arity (P/N) of all program heads. 
% For each of them we insert in Vertexes the element 
%       vertex(P/N,Es,0,0,undef).
%  Es is the edges for that predicate 
%-------------------------------------------------------------------------

init_depends([P/N|Ps],[vertex(P/N,E,0,0,undef)|Vs],[Es|Edges]):-
    ord_remove(Es,P/N,E),
    init_depends(Ps,Vs,Edges).
init_depends([],[],[]).

%-------------------------------------------------------------------------
:- export(user_clauses/5).
% user_clauses(+,+,+,+,-)
% user_clauses(Clauses,Calls,Preds,EsIn,EsOut) 
%  Collects all the user predicates called by each predicate (edges)
%-------------------------------------------------------------------------

user_clauses([],[],_,Cls,Cls).
user_clauses([Cl:_|Rest],[C|Calls],Preds,ClsIn,Cls):-
    user_clause(Cl,C,Preds,ClsIn,Cls1),
    user_clauses(Rest,Calls,Preds,Cls1,Cls).

user_clause(directive(_),[],_Preds,Cls,Cls).
user_clause(clause(H,_),C,Preds,ClsIn,Cls1):-
    add_clause(C,H,Preds,ClsIn,Cls1).

add_clause([],_,_,ThisCls,ThisCls):-!.
add_clause(C,H,[P/N|_],[ThisCls|Cls],[NewCls|Cls]):-
    functor(H,P,N),
    !,
    merge(ThisCls,C,NewCls).
add_clause(C,H,[_|Preds],[ThisCls|Cls],[ThisCls|NewCls]):-
    add_clause(C,H,Preds,Cls,NewCls).

%-----------------------------------------------------------------------------
% Main steps of the algorithm
%-----------------------------------------------------------------------------

step2(S,Cs) :-
    next_vertex(S,S1),
    step3(S1,Cs).

step3(S1,Cs) :-
    S1 = state(_,vertex(_,[],_,_,_),_,_),!,
    step7(S1,Cs).
step3(S1,Cs) :-
    S1 = state(G,vertex(V,[U|Us],K,L,F),S,I),
    get_vertex(U,G,Urec),!,
    update_vertex(vertex(V,Us,K,L,F),G,G1),
    S2 = state(G1,vertex(V,Us,K,L,F),S,I),
    step4(S2,Urec,Cs).
step3(S1,Cs) :- % we ignore predicates not yet defined(GPS)
    S1 = state(G,vertex(V,[_|Us],K,L,F),S,I),
    update_vertex(vertex(V,Us,K,L,F),G,G1),
    S2 = state(G1,vertex(V,Us,K,L,F),S,I),
    step3(S2,Cs).

step4(S1,U,Cs) :-
    new_vertex(U,S1,S2), !,
    step2(S2,Cs).
step4(S1,U,Cs) :-
    step5(S1,U,Cs).

step5(S1,U,Cs) :-
    U = vertex(_,_,KU,_,_),
    S1 = state(_,vertex(_,_,KV,_,_),_,_),
    KU > KV,!,
    step3(S1,Cs).
step5(S1,U,Cs) :-
    S1 = state(_,_,S,_),
    U = vertex(V,_,_,_,_),
    \+ memb1(V,S),!,
    step3(S1,Cs).
step5(S1,U,Cs) :-
    step6(S1,U,Cs).

step6(S1,U,Cs) :-
    S1 = state(G,vertex(V,Es,KV,LV,FV),S,I),
    U = vertex(_,_,KU,_,_),
    min(LV,KU,LV1),
    NewU =  vertex(V,Es,KV,LV1,FV),
    update_vertex(NewU,G,G1),
    S2 = state(G1,NewU,S,I),
    step3(S2,Cs).

step7(S1,[C|Cs]) :-
    S1 = state(G,U,S,I),
    U = vertex(V,_,LV,LV,_),!,
    pop(S,V,S3,C),
    S2 = state(G,U,S3,I),
    step8(S2,Cs).
step7(S1,Cs) :-
    step8(S1,Cs).

step8(S1,Cs) :-
    S1 =  state(G,vertex(_,_,_,L,F),S,I),
    \+ F = undef,!,
    get_vertex(F,G,vertex(F,FEs,KF,LF,FF)),
    min(LF,L,L1),
    update_vertex(vertex(F,FEs,KF,L1,FF),G,G1),
    S2 = state(G1,vertex(F,FEs,KF,L1,FF),S,I),
    step3(S2,Cs).
step8(S1,Cs) :-
    step9(S1,Cs).

step9(S1,Cs) :-
    S1 = state(G,_,S,I),
    newstart(G,U),!,
    S2 = state(G,U,S,I),
    step2(S2,Cs).
step9(_,[]).

%-----------------------------------------------------------------------------
% next_vertex(+,-)
% next_vertex(State,NewState)
% It updates the current vertex (second argument in State) in
% the list of vertex G (first argument in State) obtaining G1. Then it
% adds the key V of the current vertex in S (processed vertex). Finally
% it  creates a new state NewState = state(G1,UpadtedVertex,[V|S],I1)
%-----------------------------------------------------------------------------

next_vertex(state(G,vertex(V,Es,_,_,F),S,I),
            state(G1,vertex(V,Es,I1,I1,F),[V|S],I1)) :-
    I1 is I+1,
    update_vertex(vertex(V,Es,I1,I1,F),G,G1).
    
%-----------------------------------------------------------------------------
%-----------------------------------------------------------------------------

new_vertex(vertex(U,Es,0,L,_),state(G,vertex(V,_,_,_,_),S,I),
            state(G1,vertex(U,Es,0,L,V),S,I)) :-
    update_vertex(vertex(U,Es,0,L,V),G,G1).

%-----------------------------------------------------------------------------
:- export(get_vertex/3).
% get_vertex(+,+,-)
% get_vertex(V,Vertexs,Vertex) 
% Finds the vertex with key V in the set of vertex Vertexs
%-----------------------------------------------------------------------------

get_vertex(V,[vertex(V,Es,K,L,F)|_],vertex(V,Es,K,L,F)) :- !.
get_vertex(V,[_|G],Vrec) :-
    get_vertex(V,G,Vrec).

%-----------------------------------------------------------------------------
% pop(Vs,V,Rest,Init)
% Succeeds is F is in Vs
% Splits the list Vs into two lists: Init is the set of elements of Vs
% which appears in Vs before V, including V. Rest is the rest of Vs
%-----------------------------------------------------------------------------

pop([V|S],V,S,[V]) :- !.
pop([U|S],V,S1,[U|C]) :-
    pop(S,V,S1,C).

%-----------------------------------------------------------------------------
% newstart(+,-)
% newstart(Vertexs,Vertex)
% Succeeds if there is a Vertex in Vertexs, s.t. K = 0.
%-----------------------------------------------------------------------------

newstart([vertex(V,Es,0,L,F)|_],U) :-   !, U = vertex(V,Es,0,L,F).
newstart([_|G],V) :-
    newstart(G,V).
    
%-----------------------------------------------------------------------------
% update_vertex(+,+,-)
% update_vertex(vertex(V,Es,K,L,F),Vertexs,UpdatedVertex)
% It finds the vertex with key V in Vertexs and updates it with 
% the new Es,K,L,F.
%-----------------------------------------------------------------------------

update_vertex(vertex(V,Es,K,L,F),[OldVertex|G],NewVertexs) :- 
    OldVertex = vertex(V,_,_,_,_),!,
    NewVertexs = [vertex(V,Es,K,L,F)|G].
update_vertex(Y,[V|G],[V|G1]) :-
    update_vertex(Y,G,G1).

%-----------------------------------------------------------------------------

min(X,Y,Y) :- X > Y,!.
min(X,_,X).

memb1(X,[X|_]) :- !.
memb1(X,[_|Y]) :-
    memb1(X,Y).

%-----------------------------------------------------------------------------
% recursive_classify(+,+,-,-)
% recursive_classify(Clauses,Sccs,ClausesRFlags,RPs)
% For each Clause in Clauses (not directives) it adds a flag in ClausesRFlags
% indicating the recursiveness characteristics of the clause.
% RPs are the recursive predicates found.
%-----------------------------------------------------------------------------
:- if(defined(tarjan_list)).
recursive_classify(Cs,(Calls,RC),SCs,RPs):-
    recursive_classify_(Cs,Calls,RC,SCs,RPs0),
    sort(RPs0,RPs).
:- else.
recursive_classify(Cs,_,SCs,RPs):-
    program_recursive_classify(Cs, SCs, RPs0),
    sort(RPs0,RPs).
% This `sort` is only for later ord_member in
% transform:determine_r_flag, in program_recursive_classify we assert
% the recursive predicates (also useful for incremental tarjan)
:- endif.

recursive_classify_([],[],_,[],[]).
recursive_classify_([Cl:_|Cs],[C|Calls],RC,[SC|SCs],RPs):-
    classify_clause(Cl,C,RC,SC,RPs,RPs1),
    recursive_classify_(Cs,Calls,RC,SCs,RPs1).

classify_clause(directive(_),[],_RC,d,RPs,RPs).
classify_clause(clause(H,_),C,RC,REC,RPs,RPs1):-
    functor(H,N,A),
    get_recursivity_class(N/A,RC,Class),
    % Class is the set of P/N corresponding to the recursivity class 
    % to which the head N/A of the current clause belongs to.
    intersection(Class,C,Inters),
    is_rec_clause(Inters,N,A,REC,RPs,RPs1).

%-----------------------------------------------------------------------------
% fake_recursive_classify(+,-)
% fake_recursive_classify(Clauses,ClausesRFlags)
% For each Clause in Clauses (not directives) it adds a flag in ClausesRFlags
% which is always nr. This is useful when we do not care whether it is recursive 
% or not. 
%-----------------------------------------------------------------------------

fake_recursive_classify([],[]).
fake_recursive_classify([directive(_):_|Cs],[d|SCs]):-
    fake_recursive_classify(Cs,SCs).
fake_recursive_classify([clause(_,_):_|Cs],[r|SCs]):-
    fake_recursive_classify(Cs,SCs).

%-----------------------------------------------------------------------------
:- export(get_recursivity_class/3).
% get_recursivity_class(+,+,-)
% get_recursivity_class(N/A,Refs,List)
% If N/A is in some class of recursive predicates, it returns in List the
% class to which N/A belongs to. Otherwise (is non recursive) it returns 
% the empty list
%-----------------------------------------------------------------------------

get_recursivity_class(N/A,[Class|_],Class):-
    member(N/A,Class),!.
get_recursivity_class(N/A,[_|Rs],Class):- !,
    get_recursivity_class(N/A,Rs,Class).
get_recursivity_class(N/A,[],[N/A]).

:- if(defined(tarjan_list)).
recursive_class(PA,Class):-
    recursive_classes(RC),
    get_recursivity_class(PA,RC,Class).

:- else.
recursive_class(PA,Class):-
    program_recursive_class(PA, Class).
:- endif.

%-----------------------------------------------------------------------------
% is_rec_clause(+,+,+,-,?,?)
% is_rec_clause(Inter,N,A,REC,RPs,TailRPs)
% If there is a literal in Body which belongs to the same recursive 
% class, REC will be r (recursive), Inter is non-empty.
%-----------------------------------------------------------------------------
% [IG] Also collects all recursive predicates in the last argument
is_rec_clause([],_,_,nr,X,X).
is_rec_clause(L,_,_,r,NRPs,RPs) :-
    L = [_|_],
    current_pp_flag(incremental, on), !,
    append(L, RPs, NRPs).
is_rec_clause([_|_],N,A,r,[N/A|RPs],RPs).

:- doc(section, "Preproc meta calls").

:- use_module(ciaopp(p_unit/itf_db)).
:- use_module(ciaopp(p_unit/assrt_db)).
% Add entries for all the calls to meta_predicates

:- pred create_entries(+Goal,+Type,+Meta,+Mod) #"@var{Meta} is the info in the
@tt{meta_predicate} directive. ".
create_entries(_Goal,_Type,_Meta,_Mod) :-
    current_pp_flag(auto_entries_meta, off), !.
create_entries(Goal,Type,Meta,Mod) :-
    Goal =.. [_|GArgs],
    Type =.. [_|TArgs],
    Meta =.. [_|MArgs],
    create_entries_args(GArgs,TArgs,MArgs,Mod).

% TODO: addmodule annotations are not handled because they are not currently
% supported in ciaopp
create_entries_args([],[],[],_).
create_entries_args([GA|GArgs],[TA|TArgs],[MA|MArgs],M) :-
    create_entry_arg(MA,GA,TA,M),
    create_entries_args(GArgs,TArgs,MArgs,M).

create_entry_arg('?',_,_,_) :- !. % no meta
create_entry_arg(_,'$'(_Pred,Goal:LitKey,_),_TA,_ClMod) :-
    nonvar(Goal), !,
    get_module_from_sg(Goal,M),
    add_new_entry(Goal,M,LitKey).
create_entry_arg(pred(_N),'$'(Goal,Goal:LitKey,_),_TA,ClMod) :-
    % nothing can be assumed because of predicate abstractions
    ( % (failure-driven loop)
      visible(G,ClMod),
        get_module_from_sg(G,M), % filter here loaded modules
        add_new_entry(G,M,LitKey),
        fail
    ;
        true
    ).
create_entry_arg(goal,'$'(Goal,Goal:LitKey,goal),_,ClMod):-
    ( % (failure-driven loop)
      visible(G,ClMod), % what if there is more than one module loaded?
       % visible is defines, imports, or multifile.
        get_module_from_sg(G,M), % filter here loadable modules, i.e.,
        add_new_entry(G,M,LitKey),
        fail
    ; true).

% visible definition is wrong in itf_db.pl
visible(G,Mod) :-
    current_itf(imports,G,Mod).
visible(G,Mod) :-
    current_itf(defines_pred,G,Mod).
visible(G,Mod) :- % TODO: why Mod here?
    current_itf(multifile,G,Mod).

add_new_entry(G,M,LitKey) :-
    atom_codes(LitKey,LitKeyS),
    add_assertion_read(G,M,true,entry,'::'(G,'=>'([]:[],[]+[]#"Possible meta call at: "||LitKeyS)),[],'',0,0).
