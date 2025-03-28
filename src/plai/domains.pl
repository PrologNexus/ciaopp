:- module(domains, [], [assertions,regtypes,modes,nativeprops,ciaopp(ciaopp_options)]).

%:- doc(title,"Plug-in points for abstract domains").
:- doc(title,"Domain Interface for Defining Abstract Domains").

:- doc(author,"Maria Garcia de la Banda").
:- doc(author,"Francisco Bueno").
:- doc(author,"Jose F. Morales (aidomain package)").

:- doc(module,"This module contains the predicates that can be used to
   define the abstract operations that correspond to an analysis
   domain. The name of the domain is given as first argument to all
   predicates. Thus, whenever a new domain is added to the system, a
   new clause for each predicate exported here will be needed to be
   defined in the new domain's module without featuring the first
   argument. 

   Notice that not all the operations  need to be implemented in order
   to define  an abstract domain in  PLAI. Some are optional  and only
   required to accelerate or guarantee the  convergence (for instance
   @tt{widen/3}) while  other  are  only  required  if  some  special
   fixpoints.
   Some local operations used but not exported by this module would
   have to be defined, too. See the following chapter for an example
   domain module.
   In this chapter, arguments referred to as @tt{Sv}, @tt{Hv},
   @tt{Fv}, @tt{Qv}, @tt{Vars} are lists of program variables and are
   supposed to always be sorted. Abstract substitutions are referred
   to as @tt{ASub}, and are also supposed sorted (except where
   indicated), although this depends on the domain. 

@section{Variable naming convention for CiaoPP domains}

Both in the PLAI fixpoints and domains, for simplicity, we use the following
variable name meanings:

@begin{itemize}
@item @var{AbsInt}  : Identifier of the abstract domain being used.
@item @var{Sg}      : Subgoal being analysed.
@item @var{SgKey}   : Subgoal key (represented by functor/arity).
@item @var{Head}    : Head of the clause being analysed.
@item @var{Sv}      : Subgoal variables.
@item @var{Hv}      : Head variables.
@item @var{Fv}      : Free variables in the body of the clause being considered.
@item @var{Vars}    : Any possible set of variables.
@item @var{Call}    : Abstract call substitution.
@item @var{Proj}    : @var{Call} projected onto @var{Sv}.
@item @var{Entry}   : Abstract entry substitution (i.e. the abstract subtitution
      obtained after the abstract unification of @var{Sg} and @var{Head}
       projected onto @var{Hv} + @var{Fv}).
@item @var{Exit}    : Abstract exit substitution (i.e. the abstract subtitution
obtained after the analysis of the clause being considered
 projected onto @var{Hv}).
@item @var{Prime}   : Abstract prime substitution (i.e. the abstract subtitution
       obtained after the analysis of the clause being considered
        projected onto @var{Sv}).
@item @var{Succ}    : Abstract success substitution (i.e. the abstract subtitution
        obtained after the analysis of the clause being considered
        extended to the variables of the clause in which Sg appears).
@item @var{ASub}    : Any possible abstract substitution.
@item @var{R_flag}  : Flag which represents the recursive characteristics of a
        predicate. It will be ``nr'' in case the predicate be non
        recursive. Otherwise it will be r (recursive).
@item @var{List}     : (can be represented as @var{OldList},@var{List},@var{AddList},@var{IdList},@var{NewList})
        current the list of nodes which a given node depends on.
@item @var{_s}       : The suffix @var{_s} means that the term to which the variable is
        bound to has been sorted. By default they are always sorted
        thus @var{_s} is added only when it appears neccessary to say it
        explicitely.
@item @var{_uns}     : The suffix @var{_uns} means that the term to which the variable
        is bound is not sorted.
@item @var{ExtraInfo}: Info computed during the @pred{call_to_entry} that can be reused
        during the @pred{exit_to_prime} step.
 @end{itemize}
").

:- doc(bug,"When interpreting assertions (and native) should take 
    into account things like sourcename(X):- atom(X) and
    true pred atom(X) => atm(X).").
:- doc(bug,"@pred{body_succ_builtin/9} seems to introduce spurious 
    choice-points.").
:- doc(bug,"Property @tt{covered/2} is not well understood by the
    domains.").
:- doc(bug,"Operation @tt{amgu/5} is missing.").

% TODO: Define extend/5 and project/5 without the extra Subgoal
% argument.  Define extend/6 and project/6 just for those domains and
% fixpoints that require them.

% ===========================================================================

:- use_module(library(compiler/p_unit), [native_to_props/2, prop_to_native/2]).
:- use_module(ciaopp(plai/fixpo_ops), [each_exit_to_prime/8, each_abs_sort/3]).

:- use_module(library(terms_check), [variant/2]).
:- use_module(library(terms_vars),  [varset/2]).
%:- use_module(library(assertions/native_props), [linear/1]).
:- use_module(library(assertions/native_props_rtc), [rtc_linear/1]). % TODO: code that implements rtc_linear/1 should be in terms_check (like variant/2, etc.)

:- use_module(library(terms_check), [instance/2]).

:- use_module(ciaopp(infer/low_level_props), [decide_low_level_format/4]).

%------------------------------------------------------------------------%
%                    Meaning of the Program Variables                    %
%                                                                        %
%  AbsInt  : Identifier of the abstract domain being used           %
%  Sg      : Subgoal being analysed                                      %
%  SgKey   : Subgoal key (represented by functor/arity)                  %
%  Head    : Head of the clause being analysed                           %
%  Sv      : Subgoal variables                                           %
%  Hv      : Head variables                                              %
%  Fv      : Free variables in the body of the clause being considered   %
%  Vars    : Any possible set of variables                               %
%  Call    : Abstract call substitution                                  %
%  Proj    : Call projected onto Sv                                      %
%  Entry   : Abstract entry substitution (i.e. the abstract subtitution  %
%            obtained after the abstract unification of Sg and Head      %
%            projected onto Hv + Fv)                                     %
%  Exit    : Abstract exit substitution (i.e. the abstract subtitution   %
%            obtained after the analysis of the clause being considered  %
%            projected onto Hv)                                          %
%  Prime   : Abstract prime substitution (i.e. the abstract subtitution  %
%            obtained after the analysis of the clause being considered  %
%            projected onto Sv)                                          %
%  Succ    : Abstract success substitution (i.e. the abstract subtitution%
%            obtained after the analysis of the clause being considered  %
%            extended to the variables of the clause in which Sg appears)%
%  ASub    : Any possible abstract substitution                          %
%  R_flag  : Flag which represents the recursive characteristics of a    %
%            predicate. It will be "nr" in case the predicate be non     % 
%            recursive. Otherwise it will be r (recursive)
% List     : (can be represented as OldList,List,AddList,IdList,NewList) %
%            current the list of nodes which a given node depends on.    %
% _s       : The suffix _s means that the term to which the variable is  %
%            bound to has been sorted. By default they are always sorted %
%            thus _s is added only when it appears neccessary to say it  %
%            explicitely                                                 %
% _uns     : The suffix _uns means that the term to which the variable   %
%            is bound is not sorted                                      %
% ExtraInfo: Info computed during the call_to_entry that can be reused   %
%            during the exit_to_prime step                               %
%------------------------------------------------------------------------%

% ===========================================================================
:- doc(section, "Domain declaration").

:- doc(aidomain(AbsInt),"Declares that @var{AbsInt} identifies
    an abstract domain.").
:- multifile aidomain/1. % TODO: remove this multifile decl (and others)

% ===========================================================================
:- doc(section, "Initialization").

:- export(init_abstract_domain/2).
:- pred init_abstract_domain(+AbsInt, -PushedFlags) : atm(AbsInt)
   # "Initializes abstract domain @var{AbsInt}. Tells the list of
   modified (pushed) PP flags to pop afterwards.  ".
% TODO: This initialization predicate silently overwrites some
%   pp_flags. This may be very confusing for the user.
% TODO: This should be part of the definition of the domain. 
%% terms_init:- repush_types.

% ===========================================================================
:- doc(section, "Basic domain operations").

% (for fixpo_bu)
:- export(amgu/5).
:- pred amgu(+AbsInt,+Sg,+Head,+ASub,-AMGU) : atm(AbsInt) + not_fails
   # "Perform the abstract unification @var{AMGU} between @var{Sg} and
   @var{Head} given an initial abstract substitution @var{ASub} and
   abstract domain @var{AbsInt}.".

% (for fixpo_bu)
:- export(augment_asub/4).
:- pred augment_asub(+AbsInt,+ASub,+Vars,-ASub0)
   # "Augment the abstract substitution @var{ASub} adding the
   variables @var{Vars} and then resulting the abstract substitution
   @var{ASub0}.".

% (for fixpo_bu)
:- export(augment_two_asub/4).
:- pred augment_two_asub(+AbsInt,+ASub0,+ASub1,-ASub)
   # "@var{ASub} is an abstract substitution resulting of augmenting
       two abstract substitutions: @var{ASub0} and @var{ASub1} whose
       domains are disjoint.".

:- export(call_to_entry/10).
:- pred call_to_entry(+AbsInt,+Sv,+Sg,+Hv,+Head,+ClauseKey,+Fv,+Proj,-Entry,-ExtraInfo)
   : (atm(AbsInt), list(Sv), list(Hv), list(Fv)) + (not_fails, is_det)
   # "Obtains the abstract substitution @var{Entry} which results from
   adding the abstraction of the unification @var{Sg} = @var{Head} to
   abstract substitution @var{Proj} (the call substitution for
   @var{Sg} projected on its variables @var{Sv}) and then projecting
   the resulting substitution onto @var{Hv} (the variables of
   @var{Head}) plus @var{Fv} (the free variables of the relevant
   clause). @var{ExtraInfo} is information which may be reused later
   in other abstract operations.

   @begin{alert}
   @bf{Assumtions}: This predicate assumes that the variables in @var{Sv} and
   @var{Proj} are sorted (see sortedness for each domain).
   @end{alert}".
% TODO: Document ClauseKey (required by res_plai)
% TODO: Document ClauseKey=not_provided

:- export(exit_to_prime/8).
:- pred exit_to_prime(+AbsInt,+Sg,+Hv,+Head,+Sv,+Exit,?ExtraInfo,-Prime)
   : (atm(AbsInt), list(var,Hv), list(var, Sv)) + not_fails
   #"Computes the abstract substitution @var{Prime} which results from
   adding the abstraction of the unification @var{Sg} = @var{Head} to
   abstract substitution @var{Exit} (the exit substitution for a
   clause @var{Head} projected over its variables @var{Hv}),
   projecting the resulting substitution onto @var{Sv}.".

% TODO:[new-resources] compatibility with project/5 (unbound Sg!)
:- export(project/5).
:- pred project(+AbsInt,+Vars,+HvFv_u,+ASub,-Proj)
   : atm * list * list * term * term + (not_fails, is_det)
   #"Projects the abstract substitution @var{ASub} onto the variables of
   list @var{Vars} resulting in the projected abstract substitution
   @var{Proj}.".
project(AbsInt,Vars,HvFv,ASub,Proj) :-
    project(AbsInt,sg_not_provided,Vars,HvFv,ASub,Proj). % TODO: Unbound Sg is a problem! (IG) Using sg_not_provided instead (JF)

% TODO:[new-resources] version with Sg, really needed?
% TODO: check that HvFv is sorted?
:- export(project/6). % TODO:[new-resources] (extra)
:- pred project(+AbsInt,+Sg,+Vars,+HvFv_u,+ASub,-Proj)
   : atm * term * list * list * term * term + (not_fails, is_det)
   #"Projects the abstract substitution @var{ASub} onto the variables of
   list @var{Vars} resulting in the projected abstract substitution
   @var{Proj}.".

:- export(needs/2).
:- pred needs(+AbsInt,+Op) + is_det
   #"Succeeds if @var{AbsInt} needs operation @var{Op} for
    correctness/termination. It must only be used for checking, not enumerating.
    The supported operations are: @tt{widen} (whether widening is necessary for
    termination), @tt{clauses_lub} (whether the lub must be performed over the
    abstract substitution split by clase), @tt{split_combined_domain} (whether
    the domain contains information of several domains and it needs to be
    split), and @tt{aux_info} (whether the information in the abstract
    substitutions is not complete and an external solver may be needed,
    currently only used when outputing the analysis in a @tt{.dump} file)".

:- export(widencall/4).
:- pred widencall(+AbsInt,+ASub0,+ASub1,-ASub) : atm(AbsInt)
   #"@var{ASub} is the result of widening abstract substitution @var{ASub0}
   and @var{ASub1}, which are supposed to be consecutive call patterns in
   a fixpoint computation.

   @begin{alert} This predicate is allowed to fail and it fails if the
   domain does not define a widening on calls.
   @end{alert} ".

:- export(dual_widencall/4).
:- pred dual_widencall(+AbsInt,+ASub0,+ASub1,-ASub)  
   # "@var{ASub} is the result of dual widening abstract substitution
   @var{ASub0} and @var{ASub1}, which are supposed to be consecutive
   call patterns in a fixpoint computation.". 
dual_widencall(_AbsInt,_ASub0,_ASub1,_ASub) :- fail.
% TODO: [IG]This is only used in fixpo_plai_gfp.

:- export(widen/4).
:- pred widen(+AbsInt,+ASub0,+ASub1,-ASub) : atm(AbsInt) + not_fails
   #"@var{ASub} is the result of widening abstract substitution @var{ASub0} and
   @var{ASub1}, which are supposed to be consecutive approximations to the same
   abstract value. I.e., @tt{less_or_equal(AbsInt,ASub0,ASub1)} succeeds.".

% (for fixpo_plai_gfp) % TODO: see note below
:- export(dual_widen/4).
:- pred dual_widen(+AbsInt,+ASub0,+ASub1,-ASub)
   # "@var{ASub} is the result of dual widening abstract substitution
   @var{ASub0} and @var{ASub1}, which are supposed to be consecutive
   approximations to the same abstract value.". 

dual_widen(AbsInt,Prime0,Prime1,NewPrime) :-
    compute_glb(AbsInt,[Prime0,Prime1],NewPrime).
% TODO: [IG] I think this name is not correct to perform the glb
% TODO: only used in fixpo_plai_gfp and fixpo_ops_gfp

:- export(normalize_asub/3).
% normalize_asub(+,+,-)
:- pred normalize_asub(+AbsInt, +ASub0, -ASub1)
   # "@var{ASub1} is the result of normalizing abstract substitution
   @var{ASub0}. This is required in some domains, specially to perform
   the widening.".
% some domains need normalization to perform the widening:
%% [DJ] Which domains? This predicate is never implemented
normalize_asub(_AbsInt,Prime,Prime).
% [IG] This fixpo_plai and fixpo_plai_gfp each time an internal fixpoint is
% started if the widen flag is set to on, maybe because the widening on calls is
% needed

:- export(compute_lub/3).
:- pred compute_lub(+AbsInt,+ListASub,-LubASub) : atm * list * term + (not_fails, is_det)
   #"@var{LubASub} is the least upper bound of the abstract substitutions
   in list @var{ListASub}.".

% (for fixpo_plai_gfp)
:- export(compute_glb/3).
:- pred compute_glb(+AbsInt,+ListASub,-GlbASub)
   # "@var{GlbASub} is the greatest lower bound of the abstract
   substitutions in list @var{ListASub}.".
% TODO:[new-resources] needed?
compute_glb(AbsInt,[A,B],Glb) :-
    glb(AbsInt,A,B,Glb). % For backwards compatibility

:- doc(hide,compute_clauses_lub/4).
:- export(compute_clauses_lub/4).

% (for fixpo_plai_gfp)
:- doc(hide,compute_clauses_glb/4).
:- export(compute_clauses_glb/4).

%% :- export(lub_all/4).
%% % lub_all(+,+,+,-)
%% % lub_all(AbsInt,ListPatterns,Goal,LubbedPattern)
%% % It computes the lub of a set of patterns (AGoal,AProj,APrime) wrt Goal
%% % returning the pattern (Goal,Proj,Prime)
%% 
%% lub_all(AbsInt,[(Goal0,Proj0,Prime0)|Patterns],Goal,Lub) :-
%%      varset(Goal,Hv),
%%      project_pattern(Goal0,Proj0,Prime0,AbsInt,Goal,Hv,Proj,Prime),
%%      lub_all0(Patterns,Goal,Hv,Proj,Prime,AbsInt,Lub).
%% 
%% lub_all0([(Goal0,Proj0,Prime0)|Patterns],Goal,Hv,Proj1,Prime1,AbsInt,Lub) :-
%%      project_pattern(Goal0,Proj0,Prime0,AbsInt,Goal,Hv,Proj2,Prime2),
%%      compute_lub_el(AbsInt,Proj1,Proj2,Proj),
%%      compute_lub_el(AbsInt,Prime1,Prime2,Prime),
%%      lub_all0(Patterns,Goal,Hv,Proj,Prime,AbsInt,Lub).
%% lub_all0([],Goal,_Hv,Proj,Prime,_AbsInt,(Goal,Proj,Prime)).
%% 
%% project_pattern(Goal0,Proj0,Prime0,AbsInt,Goal,Hv,Proj,Prime) :-
%%      varset(Goal0,Sv),
%%      abs_sort(AbsInt,Proj0,Proj_s),
%%      call_to_entry0(Proj_s,AbsInt,Sv,Goal0,Hv,Goal,[],Proj,_),
%%      abs_sort(AbsInt,Prime0,Prime_s),
%%      call_to_entry0(Prime_s,AbsInt,Sv,Goal0,Hv,Goal,[],Prime,_).
%% 
%% call_to_entry0('$bottom',_AbsInt,_Sv,_Goal0,_Hv,_Goal,_Fv,'$bottom',_E) :- !.
%% call_to_entry0(Proj_s,AbsInt,Sv,Goal0,Hv,Goal,Fv,Proj,E) :-
%%      call_to_entry(AbsInt,Sv,Goal0,Hv,Goal,not_provided,Fv,Proj_s,Proj,E).

:- export(identical_proj/5).
:- pred identical_proj(+AbsInt,+Sg,+Proj,+Sg1,+Proj1) : atm(AbsInt)
   #"Abstract patterns @var{Sg}:@var{Proj} and @var{Sg1}:@var{Proj1} are
   equivalent in domain @var{AbsInt}. Note that @var{Proj} is assumed to
   be already sorted.
   @begin{alert}
   This predicate unifies @var{Sg} and @var{Sg1}.
   @end{alert}
   ".
identical_proj(AbsInt,Sg,Proj,Sg1,Proj1) :-
    variant(Sg,Sg1),
    Sg = Sg1,
    abs_sort(AbsInt,Proj1,Proj1_s),
    identical_abstract(AbsInt,Proj,Proj1_s).

% TODO: This predicate should be renamed to identical_complete because it also
% checks Primes
:- export(identical_proj_1/7).
:- pred identical_proj_1(+AbsInt,+Sg,+Proj,+Sg1,+Proj1,+Prime1,+Prime2)
   #"Abstract patterns @var{Sg}:@var{Proj} and @var{Sg1}:@var{Proj1} are
   equivalent in domain @var{AbsInt}. Note that @var{Proj} is assumed to be
   already sorted. It is different from @tt{identical_proj/5} because it can be
   true although @var{Sg} and @var{Sg1} are not variant".
identical_proj_1(AbsInt,Sg,Proj,Sg1,Proj1,Prime1,Prime2) :-
    \+ variant(Sg,Sg1),
    rtc_linear(Sg1),
    %
    varset(Sg1,Hv),
    varset(Sg,Hvv),
    %
    functor(Sg,F,A),
    functor(Norm,F,A),
    varset(Norm,Hvnorm),
    %
    call_to_entry(AbsInt,_Sv,Sg,Hvnorm,Norm,not_provided,[],Proj,Entry,_), % TODO: add some ClauseKey? (JF)
    call_to_entry(AbsInt,_Sv,Sg1,Hvnorm,Norm,not_provided,[],Proj1,Entry1,_), % TODO: add some ClauseKey? (JF)
    identical_abstract(AbsInt,Entry,Entry1),
    %
    % call_to_entry(AbsInt,_Sv,Sg,Hv,Sg1,not_provided,[],Proj,Entry,_),
    % abs_sort(AbsInt,Entry,Entry_s),
    % abs_sort(AbsInt,Proj1,Proj1_s),
    % identical_abstract(AbsInt,Proj1_s,Entry_s),
    %
    % call_to_entry(AbsInt,_Sv,Sg1,Hvv,Sg,not_provided,[],Proj1,Entry1,_),
    % abs_sort(AbsInt,Entry1,Entry1_s),
    % abs_sort(AbsInt,Proj,Proj_s),
    % identical_abstract(AbsInt,Proj_s,Entry1_s),
    %
    each_abs_sort(Prime1,AbsInt,Prime1_s),
    each_exit_to_prime(Prime1_s,AbsInt,Sg,Hv,Sg1,Hvv,(no,Proj),Prime2).

:- export(identical_abstract/3).
:- pred identical_abstract(+AbsInt,+ASub1,+ASub2) : atm(AbsInt)
   #"Succeeds if, in the particular abstract domain, the two abstract
   substitutions @var{ASub1} and @var{ASub2} are defined on the same
   variables and are equivalent.".
% TODO: [IG] This should be implemented in each domain

:- doc(hide,fixpoint_covered/3).
:- export(fixpoint_covered/3).

% (for fixpo_plai_gfp)
:- doc(hide,fixpoint_covered_gfp/3).
:- export(fixpoint_covered_gfp/3).

:- export(abs_sort/3).
:- pred abs_sort(+AbsInt,+ASub_u,ASub) : atm(AbsInt) + (not_fails, is_det)
   #"@var{ASub} is the result of sorting abstract substitution
   @var{ASub_u}.".

:- export(extend/6). % TODO:[new-resources] can Sg be avoided?
:- pred extend(+AbsInt,+Sg,+Prime,+Sv,+Call,-Succ) : atm(AbsInt) + (not_fails, is_det)
   #"@var{Succ} is the extension the information given by @var{Prime} (success
    abstract substitution over the goal variables @var{Sv}) to the rest of the
    variables of the clause in which the goal occurs (those over which
    abstract substitution @var{Call} is defined on). I.e., it is like a
    conjunction of the information in @var{Prime} and @var{Call}, except that
    they are defined over different sets of variables, and that @var{Prime} is
    a successor substitution to @var{Call} in the execution of the program.
    ".

:- export(less_or_equal_proj/5).
:- pred less_or_equal_proj(+AbsInt,+Sg,+Proj,+Sg1,+Proj1) : atm(AbsInt)
   #"Abstract pattern @var{Sg}:@var{Proj} is less general or equivalent to
    abstract pattern @var{Sg1}:@var{Proj1} in domain @var{AbsInt}.".
less_or_equal_proj(AbsInt,Sg,Proj,Sg1,Proj1) :-
    variant(Sg,Sg1),
    Sg = Sg1,
    abs_sort(AbsInt,Proj1,Proj1_s),
    less_or_equal(AbsInt,Proj,Proj1_s).

:- export(less_or_equal/3).
:- pred less_or_equal(+AbsInt,+ASub0,+ASub1) : atm(AbsInt)
   #"Succeeds if @var{ASub1} is more general or equivalent to @var{ASub0}.".

:- export(glb/4).
:- pred glb(+AbsInt,+ASub0,+ASub1,-GlbASub) : atm(AbsInt) + (not_fails, is_det)
   #"@var{GlbASub} is the greatest lower bound of abstract substitutions
     @var{ASub0} and @var{ASub1}.".

% ===========================================================================
:- doc(section, "Specialized operations (including builtin handling)").

:- export(eliminate_equivalent/3).
:- pred eliminate_equivalent(+AbsInt,+TmpLSucc,-LSucc)
   # "The list @var{LSucc} is reduced wrt the list @var{TmpLSucc} in
    that it does not contain abstract substitutions which are
    equivalent.".

:- export(abs_subset/3).
:- pred abs_subset(+AbsInt,+LASub1,+LASub2)
   # "Succeeds if each abstract substitution in list @var{LASub1} is
    equivalent to some abstract substitution in list @var{LASub2}.".

:- export(call_to_success_fact/10). % TODO:[new-resources] (extra)
:- pred call_to_success_fact(+AbsInt,+Sg,+Hv,+Head,+K,+Sv,+Call,+Proj,-Prime,-Succ)
   : atm(AbsInt) + not_fails
   #"Specialized version of call_to_entry + entry_to_exit + exit_to_prime
     for a fact @var{Head}.".

% TODO: fix modes, it was: special_builtin(+,+,+,-,-)
% IG: temporarily disabled +Sg because combined_special_builtin0 does not have
% the Sg and calls this predicate. Original modes:
%
% :- pred special_builtin(+AbsInt,+SgKey,+Sg,?Subgoal,-Type,-Condvars) : atm(AbsInt)
%
% DJ: disabled -CondVars, sometimes is var after execution.
:- export(special_builtin/6).
:- pred special_builtin(+AbsInt,+SgKey,?Sg,?Subgoal,-Type,?Condvars) : atm(AbsInt)
   #"Predicate @var{Sg} is considered a ""builtin"" of type @var{Type} in
     domain @var{AbsInt}. Types are domain dependent. Domains may have two
     different ways to treat these predicates: see
     @tt{body_succ_builtin/9}.".

:- doc(hide,combined_special_builtin0/3).
:- export(combined_special_builtin0/3).

:- doc(hide,split_combined_domain/4).
:- export(split_combined_domain/4).

% TODO: fix modes, it was: body_succ_builtin(+,+,+,+,+,+,+,+,-)
:- export(body_succ_builtin/9).
:- pred body_succ_builtin(+AbsInt,+Type,+Sg,?Vs,+Sv,+Hv,+Call,+Proj,-Succ)
   : atm(AbsInt) + not_fails % this predicate should not fail
   #"Specialized version of call_to_entry + entry_to_exit + exit_to_prime +
    extend for predicate @var{Sg} considered a ""builtin"" of type @var{Type}
    in domain @var{AbsInt}. Whether a predicate is ""builtin"" in a domain is
    determined by @tt{special_builtin/5}.  There are two different ways to
    treat these predicates, depending on @var{Type}: @tt{success_builtin}
    handles more usual types of ""builtins"", @tt{call_to_success_builtin}
    handles particular predicates. The later is called when @var{Type} is of
    the form @tt{special(SgKey)}.".

:- doc(doinclude,success_builtin/7).
:- export(success_builtin/7).
:- pred success_builtin(AbsInt,Type,Sv,Condvars,HvFv_u,Call,Succ)
   : atm(AbsInt) + not_fails
   #"@var{Succ} is the success substitution on domain @var{AbsInt} for a call
     @var{Call} to a goal of a ""builtin"" (domain dependent) type @var{Type}
     with variables @var{Sv}. @var{Condvars} can be used to transfer some
     information from @tt{special_builtin/5}.".

:- doc(doinclude,call_to_success_builtin/7).
:- pred call_to_success_builtin(AbsInt,Type,Sg,Sv,Call,Proj,Succ) + not_fails
   #"@var{Succ} is the success substitution on domain @var{AbsInt} for a
     call @var{Call} to a goal @var{Sg} with variables @var{Sv} considered
     of a ""builtin"" (domain dependent) type @var{Type}. @var{Proj} is
     @var{Call} projected on @var{Sv}.".

% ===========================================================================
:- doc(section, "Properties directly from domain").

:- export(obtain_info/5).
:- pred obtain_info(+AbsInt,+Prop,+Vars,+ASub,-Info) : atm(AbsInt)
   #"Obtains variables @var{Info} for which property @var{Prop} holds given
     abstract substitution @var{ASub} on variables @var{Vars} for domain
     @var{AbsInt}.".

% ===========================================================================
:- doc(section, "Properties to domain and viceversa").

:- export(info_to_asub/7).
%% TODO: DJ: Fix modes, King should be +Kind but sometimes is left as a free varible...
% Original: :- pred info_to_asub(+AbsInt,+Kind,+InputUser,+Qv,-ASub,+Sg,+MaybeCallASub)
:- pred info_to_asub(+AbsInt,?Kind,+InputUser,+Qv,-ASub,+Sg,+MaybeCallASub)
   # "Obtains the abstract substitution @var{ASub} on variables
    @var{Qv} for domain @var{AbsInt} from the user supplied
    information @var{InputUser} refering to properties on @var{Qv}. It
    works by calling @tt{input_interface/5} on each property of
    @var{InputUser} which is a native property, so that they are
    accumulated, and then calls @tt{input_user_interface/6}.".
% TODO: Document MaybeCallASub
info_to_asub(AbsInt,Kind,InputUser,Qv,ASub,Sg,MaybeCallASub) :-
    info_to_asub_(InputUser,AbsInt,Kind,_,Input),
    input_user_interface(AbsInt,Input,Qv,ASub,Sg,MaybeCallASub),
    !. % TODO: make sure that cut is not needed

% TODO: Kind is ignored! why?
info_to_asub_([],_AbsInt,_Kind,Acc,Acc).
info_to_asub_([I|Info],AbsInt,_Kind,Acc0,Acc) :-
    ( prop_to_native(I,P),
      input_interface(AbsInt,P,_Kind1,Acc0,Acc1) -> true
    ; Acc1=Acc0 ),
    info_to_asub_(Info,AbsInt,_Kind2,Acc1,Acc).

%% Commented out by PLG 8 Jun 2003
%% info_to_asub_([],_AbsInt,_Kind,Acc,Acc).
%% info_to_asub_([I|Info],AbsInt,Kind,Acc0,Acc) :-
%%      ( prop_to_native(I,P),
%%        input_interface(AbsInt,P,Kind,Acc0,Acc1) -> true
%%      ; Acc1=Acc0 ),
%%      info_to_asub_(Info,AbsInt,Kind,Acc1,Acc).

:- export(full_info_to_asub/5).
:- pred full_info_to_asub(+AbsInt,+InputUser,+Qv,-ASub,+Sg)
   # "Behaves similar as @tt{info_to_asub/7} except that
    it fails if some property in @var{InputUser} is not native or not
    relevant to the domain @var{AbsInt}.".

full_info_to_asub(AbsInt,InputUser,Qv,ASub,Sg) :-
    full_info_to_asub_(InputUser,AbsInt,_,Input),
    input_user_interface(AbsInt,Input,Qv,ASub,Sg,no),
    !. % TODO: make sure that cut is not needed

full_info_to_asub_([],_AbsInt,Acc,Acc).
full_info_to_asub_([I|Info],AbsInt,Acc0,Acc) :-
    prop_to_native(I,P),
    input_interface(AbsInt,P,perfect,Acc0,Acc1), !, % P is enough (PBC)
                                                    % do not backtrack
    full_info_to_asub_(Info,AbsInt,Acc1,Acc).       % into native_prop

:- doc(doinclude,input_interface/5).
%%% TODO: Fix modes, Kind is ignored in info_to_asub_
:- pred input_interface(+AbsInt,+Prop,?Kind,?Struc0,-Struc1)
   # "@var{Prop} is a native property that is relevant to domain
      @var{AbsInt} (i.e., the domain knows how to fully
      --@var{+Kind}=perfect-- or approximately --@var{-Kind}=approx--
      abstract it) and @var{Struct1} is a (domain defined) structure
      resulting of adding the (domain dependent) information conveyed
      by @var{Prop} to structure @var{Struct0}. This way, the
      properties relevant to a domain are being accumulated.".

:- doc(doinclude,input_user_interface/6).
%% TODO: ?Struct? Should it be +Struct?
:- pred input_user_interface(+AbsInt,?Struct,+Qv,-ASub,+Sg,+MaybeCallASub)
   # "@var{ASub} is the abstraction in @var{AbsInt} of the information
    collected in @var{Struct} (a domain defined structure) on
    variables @var{Qv}.".

:- export(asub_to_info/5).
:- pred asub_to_info(+AbsInt,+ASub,+Qv,-OutputUser,-CompProps)
   # " Transforms an abstract substitution @var{ASub} on variables
    @var{Qv} for a domain @var{AbsInt} to a list of state properties
    @var{OutputUser} and computation properties @var{CompProps}, such
    that properties are visible in the preprocessing unit. It fails if
    @var{ASub} represents bottom. It works by calling
    @tt{asub_to_native/6}.".

asub_to_info(AbsInt,ASub,Qv,OutputUser,CompProps) :-
    asub_to_native(AbsInt,ASub,Qv,no,Info,Comp),
    native_to_props(Info,OutputUser),
    native_to_props(Comp,CompProps).

:- doc(hide,asub_to_out/5).
:- export(asub_to_out/5).
asub_to_out(AbsInt,ASub,Qv,OutputUser,CompProps) :-
    asub_to_native(AbsInt,ASub,Qv,yes,Info,Comp),
    native_to_props(Info,OutputUser0),
    native_to_props(Comp,CompProps0),
    decide_low_level_format(OutputUser0,CompProps0,OutputUser,CompProps).
    
:- export(asub_to_native/6).
:- pred asub_to_native(+AbsInt,+ASub,+Qv,+OutFlag,-NativeStat,-NativeComp)
   # "@var{NativeStat} and @var{NativeComp} are the list of native
    (state and computational, resp.) properties that are the
    concretization of abstract substitution @var{ASub} on variables
    @var{Qv} for domain @var{AbsInt}. These are later translated to
    the properties which are visible in the preprocessing unit.".
% TODO: document OutFlag=yes for output

:- export(concrete/4).
:- pred concrete(+AbsInt,+Var,+ASub,-List)
   # "@var{List} are (all) the terms to which @var{Var} can be bound
    in the concretization of @var{ASub}, if they are a finite number
    of finite terms. Otherwise, the predicate fails.".

% TODO: body_succ0('$var',...) passes unbound Sg (due to metacall), use call(Sg) (or similar) instead? (JF)
:- export(unknown_call/5).
:- pred unknown_call(+AbsInt,+Sg,+Vars,+Call,-Succ)
    : (atm(AbsInt), cgoal(Sg), list(Vars)) + not_fails
    #"@var{Succ} is the result of adding to @var{Call} the ``topmost''
      abstraction in domain @var{AbsInt} of the variables @var{Vars}
      involved in a literal @var{Sg} whose definition is not present in the
      preprocessing unit. I.e., it is like the conjunction of the
      information in @var{Call} with the top for a subset of its variables.".

:- export(unknown_entry/4).
:- pred unknown_entry(+AbsInt,+Sg,+Vars,-Entry) : (atm(AbsInt), list(Vars)) + not_fails
   #"@var{Entry} is the ""topmost"" abstraction in domain @var{AbsInt} of 
    variables @var{Vars} corresponding to literal @var{Sg}.".

:- export(empty_entry/4).
:- pred empty_entry(+AbsInt,+Sg,+Vars,-Entry) : atm * cgoal * list * term + not_fails
   #"@var{Entry} is the ""empty"" abstraction in domain @var{AbsInt} of
     variables @var{Vars}. I.e., it is the abstraction of a substitution on
     @var{Vars} in which all variables are unbound: free and unaliased.".

% ===========================================================================
:- doc(section, "Other particular operations").

%% :- export(propagate_downwards_closed/4).
%% % propagate_downwards_closed(+,+,+,-)
%% % propagate_downwards_closed(AbsInt,ASub1,ASub2,ASub)
%% % Propagates the downwards closed properties from ASub1 to ASub2
%% 
%% :- export(del_real_conjoin/4).
%% % del_real_conjoin(+,+,+,-)
%% % del_real_conjoin(AbsInt,ASub1,ASub2,ASub)
%% % Propagates the downwards closed properties from ASub1 to ASub2
%% 
%% :- export(del_hash/4).
%% % del_hash(+,+,+,-)
%% % del_hash(AbsInt,ASub,Vars,N)
%% % Returns a number which identifies ASub
%% 
%% :- export(more_instantiate/3).
%% % more_instantiate(+,+,+)
%% % more_instantiate(AbsInt,ASub1,ASub2)
%% % Succesdes if ASub2 is possibly more instantiated than ASub1
%% 
%% :- export(convex_hull/4).
%% % convex_hull(+,+,+,-)
%% % convex_hull(AbsInt,ASub1,ASub2,Hull)
%% 
%% :- export(compute_lub_el/4).
%% % compute_lub_el(+,+,+,-)
%% % compute_lub_el(AbsInt,ASub1,ASub2,Lub)
%% % Lub is the lub of abstractions ASub1 and ASub2
%% 
%% :- export(extend_free/4).
%% % extend_free(+,+,+,-)
%% % extend_free(AbsInt,ASub,Vars,ExtASub)
%% % It extends ASub to the new (free) vars in Vars
%% 
%% :- export(del_check_cond/6).
%% % del_check_cond(+,+,+,+,-,-)
%% % del_check_cond(AbsInt,Cond,ASub,Sv,Flag,WConds)
%% % Determines if a subgoal is definitely awake (Flag = w), definitely
%% % delayed (Flag = d), or possibly awake (Flag = set of abstractions
%% % under which the subgoal can be woken), w.r.t. abstraction ASub
%% 
%% :- export(del_impose_cond/5).
%% % del_impose_cond(+,+,+,+,-)
%% % del_impose_cond(AbsInt,Cond,Sv,ASub,NewASub)

:- export(part_conc/5).
:- pred part_conc(+AbsInt,+Sg,+Subs,-NSg,-NSubs)
   # "This operation returns in @var{NSg} an instance of @var{Sg} in
     which the deterministic structure information available in
     @var{Subs} is materialized. The substitution @var{NSubs} refers
     to the variables in @var{NSg}.".

:- export(multi_part_conc/4).
:- pred multi_part_conc(+AbsInt,+Sg,+Subs,-List)
   # "Similar to @tt{part_conc/5} but it gives instantiations of goals
     even in the case types are not deterministic, it generates a
     @var{List} of pairs of goals and substitutions. It stops
     unfolding types as soon as they are recursive.".

% ---------------------------------------------------------------------------
% % TODO: [IG] move?

:- export(collect_types_in_abs/4).  % TODO: [IG] only used in typeslib/dumper.pl
:- pred collect_types_in_abs(+ASub,+AbsInt,Types,Tail) + (is_det, not_fails)
   #"Collects the type symbols occurring in @var{ASub} of domain @var{AbsInt} in
    a difference list @var{Types}-@var{Tail}.".
collect_types_in_abs('$bottom',_AbsInt,Types0,Types) :- !,
    Types = Types0.
collect_types_in_abs(ASub,AbsInt,Types0,Types) :-
    collect_auxinfo_asub(AbsInt,ASub,Types0,Types).

% :- export(collect_auxinfo_asub/4).

:- export(rename_types_in_abs/4).  % TODO: [IG] only used in typeslib/dumper.pl
:- pred rename_types_in_abs(+ASub0,+AbsInt,+Dict,ASub1) + (is_det, not_fails)
   #"Renames the type symbols occurring in @var{ASub0} of domain @var{AbsInt}
    for the corresponding symbols as in (avl-tree) @var{Dict} yielding
    @var{ASub1}.".
rename_types_in_abs('$bottom',_AbsInt,_Dict,ASub) :- !,
    ASub = '$bottom'.
rename_types_in_abs(ASub0,AbsInt,Dict,ASub1) :-
    rename_auxinfo_asub(AbsInt,ASub0,Dict,ASub1).

% :- export(rename_auxinfo_asub/4).

:- export(dom_statistics/2).
:- pred dom_statistics(+AbsInt, -Info)
   # "Obtains in list @var{Info} statistics about the results of the
   abstract interpreter @var{AbsInt}.".

:- export(abstract_instance/5).
:- pred abstract_instance(+AbsInt,+Sg1,+Proj1,+Sg2,+Proj2)
   #"The pair @var{<Sg1,Proj1>} is an abstract instance of the pair @var{<Sg2,Proj2>}, i.e.,
    the concretization of @var{<Sg1,Proj1>} is included in the concretization of
    @var{<Sg2,Proj2>}.".

abstract_instance(AbsInt,Sg1,Proj1,Sg2,Proj2) :- 
    part_conc(AbsInt,Sg1,Proj1,Sg1C,Proj1C),
    part_conc(AbsInt,Sg2,Proj2,Sg2C,Proj2C),
    instance(Sg1C,Sg2C),
    varset(Sg2C,S2Cv),
    varset(Sg1C,S1Cv),
    call_to_entry(AbsInt,S2Cv,Sg2C,S1Cv,Sg1C,not_provided,[],Proj2C,Entry,_ExtraInfo), % TODO: add some ClauseKey? (JF)
    Entry \== '$bottom',
    less_or_equal(AbsInt,Proj1C,Entry).

:- export(contains_parameters/2).
:- pred contains_parameters(+AbsInt,+Subst)
   # "True if an abstract substitution @var{Subst} contains type
   parameters".

% ===========================================================================

:- include(ciaopp(plai/domains_hooks)).

% ===========================================================================
% (common)

:- use_module(library(lists), [member/2]).
:- use_module(library(messages), [warning_message/2]).
:- use_module(ciaopp(preprocess_flags), [current_pp_flag/2]).

:- export(absub_eliminate_equivalent/3).
:- pred absub_eliminate_equivalent(+ASubList, +AbsInt, -NewASubList) + not_fails
   # "This predicate is already defined and should not be
     redefined. Given a list of abstractions @var{ASubList} for the
     domain @var{AbsInt}, @var{NewASubList} is a list of abstractions
     such that for each element in @var{AsubList} it is in
     @var{NewASubList} or there exists an equivalent abstraction in
     @var{NewASubList}. And for each two elements in @var{NewASubList}
     they are not equivalent abstractions.".
%% Maybe a little verbose.
absub_eliminate_equivalent([],_AbsInt,[]).
absub_eliminate_equivalent([ASub],_AbsInt,[ASub]) :- !.
absub_eliminate_equivalent([ASub|LASub],AbsInt,[ASub|NLASub]) :-
    take_equivalent_out(LASub,ASub,AbsInt,TmpLASub),
    absub_eliminate_equivalent(TmpLASub,AbsInt,NLASub).

take_equivalent_out([],_ASub,_AbsInt,[]).
take_equivalent_out([ASub0|LASub],ASub,AbsInt,NLASub) :-
    equivalent_or_not(ASub0,ASub,AbsInt,NLASub,Tail),
    take_equivalent_out(LASub,ASub,AbsInt,Tail).

equivalent_or_not(ASub0,ASub,AbsInt,NLASub,Tail) :-
    identical_abstract(AbsInt,ASub0,ASub), !,
    NLASub=Tail.
equivalent_or_not(ASub0,_ASub,_AbsInt,[ASub0|Tail],Tail).

:- doc(hide,absub_fixpoint_covered/3).
:- export(absub_fixpoint_covered/3).
:- pred absub_fixpoint_covered(+AbsInt, +Prime0, +Prime1)
   # "This predicate is already defined and should not be
     redefined. It succeeds when the abstraction @var{Prime0} is
     covered by the abstraction @var{Prime1} in the domain
     @var{AbsInt}. This predicated is used in order to check whether a
     fixpoint is reached.".
absub_fixpoint_covered(AbsInt,Prime0,Prime1) :-
    ( current_pp_flag(multi_call,on) ->
        identical_abstract(AbsInt,Prime0,Prime1)
    ; current_pp_flag(multi_call,off) ->
        less_or_equal(AbsInt,Prime0,Prime1)
    ; fail % TODO: anything else?
    ).

:- doc(hide, body_builtin/9).
:- export(body_builtin/9).
:- pred body_builtin(+AbsInt, +SgKey, +Sg, ?Condvs, +Sv, ?HvFv_u, +Call, +Proj, -Succ)
   # "This predicate is already defined and should not be redefined.
     It calls to @tt{call_to_success_builtin/6} or to
     @tt{success_builtin} in order to abstract the subgoal @var{Sg}
     received provided the information abstracted in @var{Call} and
     @var{Proj}.".
body_builtin(AbsInt,special(SgKey),Sg,_Condvs,Sv,_HvFv_u,Call,Proj,Succ) :- !,
    call_to_success_builtin(AbsInt,SgKey,Sg,Sv,Call,Proj,Succ).
body_builtin(AbsInt,Type,_Sg,Condvs,Sv,HvFv_u,Call,_Proj,Succ) :-
    success_builtin(AbsInt,Type,Sv,Condvs,HvFv_u,Call,Succ), !.
body_builtin(AbsInt,Type,_Sg,_Condvs,_Sv,_HvFv_u,_Call,_Proj,'$bottom') :-
    warning_message("body_builtin: the builtin key ~q is not defined in domain ~w",
                    [Type,AbsInt]).

:- doc(hide,undef_call_to_success_builtin/2).
:- export(undef_call_to_success_builtin/2).
:- pred undef_call_to_success_builtin(+AbsInt, +SgKey)
   # "This predefined predicate raises a warning message when a
     builtin with key @var{SgKey} that has succeeded in
     @tt{special_builtin/5} is not defined in
     @tt{call_to_success_builtin/6} or such definition fails
     (@tt{call_to_success_builtin/6} can not fail.".
undef_call_to_success_builtin(AbsInt,SgKey) :-
     warning_message("call_to_success_builtin: the builtin key ~q is
     not defined in domain ~w", [special(SgKey),AbsInt]).

