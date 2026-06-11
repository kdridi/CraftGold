Tour d'Horizon : Langages compilant vers Lua pour WoW Add-on DevelopmentL'architecture d'un add-on World of Warcraft complexe tel que CraftGold pose un défi d'ingénierie logicielle singulier. D'une part, le domaine métier exige des abstractions algorithmiques avancées : programmation dynamique (sac à dos), arbres de décision récursifs, détection de cycles, et structures de données immuables. D'autre part, la cible de compilation est un environnement d'exécution strictement contraint : l'interpréteur Lua 5.1 embarqué par le client World of Warcraft Classic Era. Cet interpréteur, bien que performant pour le scriptage d'interfaces graphiques, est dépourvu des constructions modernes nécessaires à la modélisation formelle (système de types statiques, types algébriques de données, pattern matching, structures monadiques) et impose un budget CPU par frame extrêmement strict pour éviter le gel de l'interface utilisateur.La recherche de la meilleure abstraction possible nécessite d'analyser l'écosystème des langages transpilant vers Lua sous un angle exigeant. Il s'agit d'identifier une technologie offrant une séparation étanche entre la logique pure et les effets de bord (API WoW), un système de mocking naturel dérivant du système de types, et une vérification statique robuste, tout en garantissant que le code généré respecte les limites physiques de la machine virtuelle Lua 5.1 (notamment la limite stricte de 60 upvalues par fonction et le coût du ramasse-miettes sur la création de fermetures).Résumé exécutifL'analyse exhaustive des écosystèmes compilant vers Lua révèle une tension fondamentale entre l'expressivité fonctionnelle pure et les limites de la machine virtuelle Lua 5.1. Trois candidats se distinguent pour répondre aux exigences architecturales de CraftGold, chacun incarnant un paradigme distinct.Le premier choix, TypeScriptToLua (TSTL), représente l'approche industrielle et pragmatique. Bien que TypeScript soit fondamentalement impératif, son système de types structurel, reconnu pour son expressivité, permet d'émuler parfaitement les Types Algébriques de Données (ADT) via les unions discriminées. Le code Lua généré est hautement optimisé, parfaitement compatible 5.1, et la gestion de l'asynchronisme compile de manière transparente vers des coroutines Lua. C'est la solution la plus mature pour l'écosystème WoW.Le second candidat, PureScript (via le backend pslua), incarne l'idéal théorique et le "Saint Graal" de la programmation fonctionnelle. Il offre des abstractions mathématiques pures (Monades Effect/State, ADT, Typeclasses) permettant de séparer formellement les IO de la logique algorithmique. Néanmoins, son surcoût d'exécution lié à la curryfication systématique et le statut expérimental de son backend Lua représentent un risque technique.Enfin, Fennel se positionne comme l'élégance minimaliste par excellence. Ce dialecte Lisp s'exécutant sur Lua ne présente aucun overhead (zéro coût d'abstraction). S'il fait l'impasse sur le typage statique, il compense par un système de macros métaprogrammables surpuissant, capable de valider des bases de données à la compilation, et intègre un système de pattern matching natif redoutable.Évaluation détailléePureScript (via pslua)Vue d'ensemblePureScript est un langage de programmation purement fonctionnel, fortement typé, dont la syntaxe et la sémantique s'inspirent directement de Haskell. Contrairement à ce dernier, PureScript adopte une évaluation stricte, ce qui simplifie la prédiction des performances dans des environnements contraints. Le projet pslua est un compilateur alternatif ("backend") qui ingère la représentation intermédiaire fonctionnelle de PureScript, nommée CoreFn, pour générer du code source Lua.Ce langage brille par son système de types global incluant l'inférence de types, les Types Algébriques de Données (ADT), les types de rang supérieur (HKT) et les Typeclasses. La communauté PureScript est intellectuellement très active, bien que restreinte, et le backend pslua en lui-même (initié pour interopérer avec OpenResty et Neovim) est maintenu par une poignée de contributeurs dévoués. Le compilateur génère du code compatible Lua 5.1, condition sine qua non pour l'environnement de World of Warcraft.Exemples CraftGoldLa modélisation de l'algorithme Calculator en PureScript permet de résoudre formellement l'enchevêtrement entre la logique métier et l'état mutable. L'état (pour la détection de cycles) et les effets (appels à l'Hôtel de Ventes ou aux prix manuels) sont gérés par un transformateur de monades StateT empilé sur une abstraction d'effets m.a) Calculator — calcul récursif avec State MonadL'approche retenue ici est celle du Tagless Final, une technique avancée d'injection de dépendances au niveau du système de types. L'algorithme ne sait pas comment l'API WoW est implémentée ; il exige seulement que l'environnement d'exécution (la monade m) respecte le contrat MonadWoW.Extrait de codemodule CraftGold.Calculator where

import Prelude
import Control.Monad.State (StateT, get, modify_)
import Control.Monad.Trans.Class (lift)
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.Foldable (foldM)

-- ADT strict garantissant que la méthode est exhaustivement traitée
data Method = Buy { cost :: Int } | Craft { cost :: Int, buyPrice :: Maybe Int }

-- État pour la détection de cycle (géré purement sans mutation de variables locales)
type CalcState = { visiting :: Set.Set Int }

-- L'interface d'effet pure (Tagless Final)
class Monad m <= MonadWoW m where
  getQuote :: Int -> Int -> m (Maybe Int)
  getPrice :: Int -> m (Maybe Int)
  getRecipe :: Int -> m (Maybe { reagents :: Array { id :: Int, qty :: Int } })

-- Algorithme fonctionnel pur
calculate :: forall m. MonadWoW m => Int -> Int -> StateT CalcState m (Maybe Method)
calculate itemID qty = do
  state <- get
  if Set.member itemID state.visiting then
    pure Nothing -- Cycle de craft détecté, coupure de la branche
  else do
    modify_ \s -> s { visiting = Set.insert itemID s.visiting }
    
    -- Résolution de l'option d'achat
    quote <- lift $ getQuote itemID qty
    price <- lift $ getPrice itemID
    let buyCost = case quote, price of
                    Just q, _ -> Just q
                    Nothing, Just p -> Just (p * qty)
                    Nothing, Nothing -> Nothing
    
    -- Résolution de l'option de fabrication
    recipeOpts <- lift $ getRecipe itemID
    craftCost <- case recipeOpts of
      Nothing -> pure Nothing
      Just recipe -> do
        total <- foldM (\acc reagent -> do
            res <- calculate reagent.id (reagent.qty * qty)
            pure $ acc + case res of
                           Just (Buy b) -> b.cost
                           Just (Craft c) -> c.cost
                           Nothing -> 99999999 -- Symbolise l'infini / non-craftable
          ) 0 recipe.reagents
        pure $ if total >= 99999999 then Nothing else Just total

    -- Backtracking pur
    modify_ \s -> s { visiting = Set.delete itemID s.visiting }

    -- Pattern matching final pour la décision
    pure $ case buyCost, craftCost of
      Just b, Just c | b <= c    -> Just $ Buy { cost: b }
                     | otherwise -> Just $ Craft { cost: c, buyPrice: Just b }
      Just b, Nothing            -> Just $ Buy { cost: b }
      Nothing, Just c            -> Just $ Craft { cost: c, buyPrice: Nothing }
      Nothing, Nothing           -> Nothing
b) WoW API Seam + Mocking (Tagless Final)Le mocking n'est plus un piratage de table Lua (_G ou injection globale) mais une simple définition d'instance de Typeclass. Pour le code de production dans WoW, nous utilisons l'effet natif Effect via la Foreign Function Interface (FFI) :Extrait de code-- FFI vers l'API Lua de Blizzard
foreign import wowGetItemInfo :: Int -> Effect String
foreign import wowQueryAuctionItems :: Int -> Effect Unit

newtype WoWApp a = WoWApp (Effect a)
derive newtype instance Functor WoWApp
derive newtype instance Apply WoWApp
derive newtype instance Applicative WoWApp
derive newtype instance Bind WoWApp
derive newtype instance Monad WoWApp

instance MonadWoW WoWApp where
  getQuote id qty = WoWApp $ pure Nothing -- Logique d'appel API
  getPrice id = WoWApp $ pure Nothing
  getRecipe id = WoWApp $ pure Nothing
c) Test unitairePour tester, une monade Identity ou State est substituée. Le compilateur garantit mathématiquement qu'aucune fonction WoW ne peut être appelée accidentellement.Extrait de codeimport Control.Monad.State (State, evalState)

newtype MockApp a = MockApp (State (Map Int Int) a)
-- instances Functor, Applicative, Monad...

instance MonadWoW MockApp where
  getQuote id qty = pure $ Just 800
  getPrice id = pure $ Just 1000
  getRecipe id = pure Nothing

testCalculate :: Effect Unit
testCalculate = do
  let (Tuple result _) = runStateT (calculate 4359 1) { visiting: Set.empty }
  let finalResult = evalState (unwrap result) mockDbState
  assert (finalResult == Just (Buy { cost: 800 }))
d) Code généréLe Lua 5.1 généré par pslua est fortement transformé. En raison de la sémantique de curryfication de PureScript, les fonctions prennent leurs arguments un par un.Lua-- Lua généré (conceptuel)
local calculate = function(dictMonadWoW)
  return function(itemID)
    return function(qty)
      return function(state)
        -- Logique compilée avec des fermetures successives
        local isMember = Data_Set.member(itemID)(state.visiting)
        if isMember then 
           return Data_Maybe.Nothing.value
        else
           -- ...
        end
      end
    end
  end
end
ToolingL'écosystème PureScript utilise spago pour la gestion des dépendances et purs pour la compilation vers l'IR. Le projet pslua s'intègre via un script Nix (Flake) ou via l'option --backend de Spago.
L'expérience développeur (DX) est robuste grâce au serveur de langage purescript-language-server, qui offre des diagnostics stricts et instantanés. Néanmoins, le débogage en jeu requiert des source maps complexes à configurer pour pointer vers les fichiers .purs.Optimisationspslua implémente une phase de Dead Code Elimination (DCE) agressive sur l'AST CoreFn, garantissant que seules les fonctions utilisées sont incluses dans le bundle Lua final. L'inlining est partiel.LimitesLe risque fondamental d'utiliser PureScript pour World of Warcraft réside dans l'architecture de la VM Lua 5.1. Cette dernière impose une limite matérielle de 60 upvalues (variables externes capturées par une fermeture) par fonction. La nature compositionnelle et curryfiée de PureScript génère une abondance de fermetures imbriquées. Dans des arbres de calcul profonds (comme le Calculator), cette limite peut provoquer des crashs à la transpilation ou à l'exécution. De plus, la création excessive de tables temporaires (pour simuler les ADT) génère une forte pression sur le ramasse-miettes (GC) de WoW, pouvant entraîner des chutes du nombre d'images par seconde (FPS).SourcesDocumentation PureScript / pslua GitHub repository.Rapports d'issues sur la limite des upvalues dans Lua 5.1 et luacheck.Discussions sur les FFI et l'isolation.TypeScriptToLua (TSTL)Vue d'ensembleTypeScriptToLua (TSTL) est un transpilateur qui ingère du code TypeScript standard, exploite l'AST généré par le compilateur Microsoft, et émet du code Lua sémantiquement équivalent. Créé pour faciliter le développement de mods (Dota 2, Defold, LÖVE), il s'est imposé comme le standard industriel dans la communauté de développement d'add-ons World of Warcraft.Le langage principal étant TypeScript, il utilise un système de types structurel (par opposition au typage nominal). Bien que le paradigme sous-jacent soit multi/impératif, TypeScript permet d'exprimer des concepts purement fonctionnels avec un haut niveau de sécurité. TSTL supporte de multiples versions cibles, et génère un code Lua 5.1 hautement performant, évitant intelligemment les features modernes non compatibles.Exemples CraftGoldL'expressivité de TypeScript permet d'utiliser les Discriminated Unions pour émuler le comportement strict des Types Algébriques de Données (ADT), forçant le développeur à gérer tous les cas lors de la compilation.a) Calculator — calcul récursif avec détection de cyclesIci, la logique pure est séparée des effets de bord par le biais de l'Injection de Dépendances (DI), une approche plus conventionnelle que le Tagless Final mais tout aussi efficace pour le mocking.TypeScript// ADT émulé via les Unions Discriminées
export type CalculationMethod = 
    | { kind: "buy", cost: number, craftCost?: number }
    | { kind: "craft", cost: number, buyPrice?: number };

export type CalcState = {
    visiting: Set<number>; // TSTL fournit un polyfill Set léger et performant
};

// Contrat d'interface pour l'isolation des IO
export interface IWoWContext {
    getQuote(itemID: number, qty: number): { cost: number } | undefined;
    getPrice(itemID: number): number | undefined;
    getRecipe(itemID: number): Recipe | undefined;
}

export class Calculator {
    constructor(private readonly ctx: IWoWContext) {}

    public calculate(itemID: number, qty: number = 1, state: CalcState = { visiting: new Set() }): CalculationMethod | undefined {
        // La mutation locale de Set évite la pression sur le Garbage Collector de WoW
        if (state.visiting.has(itemID)) return undefined; 
        
        state.visiting.add(itemID);

        let buyCost: number | undefined;
        const quote = this.ctx.getQuote(itemID, qty);
        if (quote) {
            buyCost = quote.cost;
        } else {
            const unitPrice = this.ctx.getPrice(itemID);
            if (unitPrice) buyCost = unitPrice * qty;
        }

        let craftCost: number | undefined;
        const recipe = this.ctx.getRecipe(itemID);
        if (recipe) {
            let total = 0;
            for (const reagent of recipe.reagents) {
                const sub = this.calculate(reagent.id, reagent.qty * qty, state);
                if (sub) {
                    total += sub.cost;
                } else {
                    total = Infinity; // Marqueur d'échec
                    break;
                }
            }
            if (total !== Infinity) craftCost = total;
        }

        state.visiting.delete(itemID); // Backtracking de l'état

        // Exhaustivité structurelle (Pattern Matching simulé)
        if (buyCost !== undefined && craftCost !== undefined) {
            return buyCost <= craftCost 
                ? { kind: "buy", cost: buyCost, craftCost: craftCost }
                : { kind: "craft", cost: craftCost, buyPrice: buyCost };
        } else if (buyCost !== undefined) {
            return { kind: "buy", cost: buyCost };
        } else if (craftCost !== undefined) {
            return { kind: "craft", cost: craftCost };
        }
        return undefined;
    }
}
b) WoW API Seam + MockingL'écosystème TSTL bénéficie de dépôts communautaires massifs définissant l'intégralité de l'API World of Warcraft sous forme de fichiers de déclaration (.d.ts). L'interface IWoWContext est implémentée pour la production en appelant l'espace global, et simulée dans les tests :TypeScript// Production
export class RealWoWContext implements IWoWContext {
    getQuote(itemID: number, qty: number) {
        // Appels directs et sûrs à C_AuctionHouse (typés par wow-declarations)
        return null;
    }
    // ...
}
c) Test unitaireLes tests s'écrivent avec des frameworks de tests standard (comme Jest) ou directement en appelant la classe avec le mock, ne nécessitant aucune intégration complexe de busted ou d'environnement de test Lua factice.TypeScripttest("chooses buy when cheaper", () => {
    const mockCtx: IWoWContext = {
        getPrice: (id) => id === 2840 ? 1000 : undefined,
        getQuote: (id, qty) => id === 4359 ? { cost: 800 } : undefined,
        getRecipe: () => undefined
    };
    
    const calc = new Calculator(mockCtx);
    const result = calc.calculate(4359);
    
    expect(result).toBeDefined();
    expect(result?.kind).toBe("buy");
    expect(result?.cost).toBe(800);
});
d) Machine à états asynchrone (Scanner) et CoroutinesL'une des prouesses technologiques de TSTL est la résolution du problème d'asynchronisme infernal de l'API WoW (les requêtes HdV nécessitent des callbacks matériels). TSTL transpile le sucre syntaxique async/await de TypeScript vers un système de coroutines Lua (coroutine.create, coroutine.yield, coroutine.resume) de manière totalement rétrocompatible avec Lua 5.1.Une machine à états complexe (IDLE → SCANNING → ACCUMULATE) s'efface au profit d'un code linéaire :TypeScriptasync function performFullScan(): Promise<void> {
    while (true) {
        const hasNextPage = await requestAuctionPage(); // Yields coroutine
        if (!hasNextPage) break;
    }
}
e) Code généréLe Lua généré par TSTL se veut le plus proche possible du code impératif optimal écrit par un humain. Les abstractions TypeScript (interfaces, types d'unions) sont complètement effacées (Type Erasure) à la compilation, ne laissant aucun surcoût au moment de l'exécution (zéro runtime overhead).Lua-- Lua 5.1 généré (simplifié et extrêmement lisible)
Calculator.prototype.calculate = function(self, itemID, qty, state)
    if qty == nil then qty = 1 end
    if state == nil then state = { visiting = __TS__New(Set) } end
    
    if state.visiting:has(itemID) then return nil end
    state.visiting:add(itemID)
    
    local buyCost = nil
    local quote = self.ctx:getQuote(itemID, qty)
    if quote then
        buyCost = quote.cost
    else
        local unitPrice = self.ctx:getPrice(itemID)
        if unitPrice then buyCost = unitPrice * qty end
    end
    -- Logique min(buy, craft)
end
ToolingL'intégration avec le workflow d'add-ons WoW est exceptionnelle. Le projet utilise npm et tsconfig.json avec la spécification "tstl": { "luaTarget": "JIT" }. Les IDE comme Visual Studio Code offrent une intégration LSP native, l'autocomplétion sur toute l'API WoW (grâce aux modules comme wow-eluna-ts-module), et la gestion des source maps pour un débogage direct.OptimisationsTSTL implémente de multiples passes d'optimisation via son AST, convertissant par exemple les boucles for...of itérant sur des types statiques stricts en boucles for numériques Lua ultra-rapides. Il inclut également des plugins pour personnaliser le comportement du compilateur.LimitesLa limitation principale de TypeScript est son typage structurel qui rend difficile la création de types opaques nominaux purs (bien que des astuces de type existent). De plus, certaines méthodes standard de JavaScript polyfillées (comme certaines opérations sur les Map/Set) peuvent occasionner de légères allocations de mémoire supplémentaires, bien que cela reste largement sous les budgets stricts de WoW.SourcesDocumentation TSTL.Exemples d'intégration WoW (Eluna, WotLK declarations).Discussions communautaires sur l'utilisation de TSTL pour les add-ons.FennelVue d'ensembleFennel est un langage de programmation à part entière, mais conçu comme un dialecte Lisp s'exécutant sur les machines virtuelles Lua. Il ne s'agit pas d'un transpilateur lourd analysant un AST étranger, mais d'une traduction macro-syntaxique directe vers Lua. Sa devise est le "zéro overhead" : le code généré est identique en performance à un Lua manuscrit optimisé. Le langage est très mature et largement adopté dans des écosystèmes contraints (LÖVE 2D, Neovim, TIC-80).Bien que Fennel soit un langage à typage dynamique (comme Lua), il introduit une discipline fonctionnelle stricte : immutabilité locale par défaut (let au lieu de variables mutables), fonctions d'ordre supérieur, et macros métaprogrammables.Exemples CraftGolda) Calculator avec Pattern Matching NatifFennel intègre une forme spéciale match qui offre un véritable pattern matching destructurel, remplaçant avantageusement les cascades de if/else de Lua.Clojure(local {: match} (require :fennel)) ; Import de la macro de pattern matching

;; La séparation IO se fait en passant un dictionnaire 'ctx' (Injection de Dépendances)
(fn calculate [ctx item-id qty state]
  (let [qty (or qty 1)
        state (or state {:visiting {}})]
    (if (. state.visiting item-id)
        nil ; Détection de cycle, coupe-circuit
        (do
          (tset state.visiting item-id true) ; Mutation locale isolée
          
          ;; Évaluation de l'achat via pattern matching
          (let [buy-cost (match (ctx.get-quote item-id qty)
                           {:cost c} c
                           _ (match (ctx.get-price item-id)
                               p (* p qty)
                               _ nil))
                
                recipe (ctx.get-recipe item-id)
                ;; Évaluation du craft via accumulateur fonctionnel
                craft-cost (when recipe
                             (accumulate [total 0
                                          _ {:id r-id :qty r-qty} (ipairs recipe.reagents)]
                               (let [sub (calculate ctx r-id (* r-qty qty) state)]
                                 (if sub (+ total sub.cost)
                                     (lua "return nil")))))] ; Interruption précoce si non craftable
            
            (tset state.visiting item-id nil) ; Nettoyage de l'état
            
            ;; Décision finale min(buy, craft)
            (match [buy-cost craft-cost]
              [b c] (if (<= b c)
                        {:method :buy :cost b :craft-cost c}
                        {:method :craft :cost c :buy-price b})
              [b nil] {:method :buy :cost b}
              [nil c] {:method :craft :cost c}
              _ nil))))))
b) Base de données déclarative (Résolution par Macros)Le problème soulevé par la base de données statique (DB.lua) trouve ici une solution élégante. Fennel autorise l'exécution de code à la compilation (macros). Au lieu de valider la conformité des 1500 recettes à l'exécution dans le jeu (ce qui consomme du CPU et de la mémoire), une macro peut ingérer la syntaxe déclarative, vérifier sa validité structurelle, et générer les tables Lua optimales.Clojure;; db-macros.fnl (Exécuté à la compilation)
(fn validate-recipe [spell-id output-id reagents]
  (assert (= (type spell-id) "number") "Le Spell ID doit être un nombre")
  (assert (> (length reagents) 0) "Une recette doit avoir des composants")
  ;; Génère l'Abstract Syntax Tree final
  `{ ,spell-id {:output ,output-id :reagents ,reagents}})

;; Utilisé dans le code
(import-macros {: validate-recipe} :db-macros)
(local recipes
  [(validate-recipe 3928 4401 [{:id 774 :qty 2} {:id 2840 :qty 1}])])
c) Code généréLe Lua 5.1 généré est structurellement pur, dénué de fonctions d'aide artificielles, respectant l'idiome de Lua. Le pattern matching se compile en une série optimisée de vérifications de conditions.Tooling et OptimisationsLe serveur de langage fennel-ls permet l'autocomplétion et le formatage. Le REPL interactif de Fennel facilite grandement le développement expérimental, bien que son intégration directe dans WoW requiert un client/serveur asynchrone. L'optimisation est inhérente : l'élimination du code s'effectue par l'expansion conditionnelle des macros.LimitesL'absence totale de typage statique force le développeur à maintenir la discipline de la structure des données (via des assertions ou des tests unitaires), ce qui contredit partiellement l'exigence de vérification statique de CraftGold. Le paradigme fonctionnel est puissant, mais les structures monadiques complexes peinent à trouver leur place de manière idiomatique dans un environnement dynamique comme Lisp.SourcesRéférence officielle de Fennel.Documentation sur le fonctionnement Lisp/Lua et les macros.Débats sur la place de Fennel par rapport aux langages statiques.Haxe (via reflaxe.lua)Vue d'ensembleHaxe est un langage de programmation à la syntaxe rigoureuse, historiquement utilisé pour cross-compiler des jeux vers de multiples cibles (C++, JavaScript, HL). Le compilateur Haxe natif inclut une cible Lua, mais le code généré souffre d'un "bloat" significatif car Haxe injecte des bibliothèques massives pour garantir que le comportement de ses classes standards est identique à travers toutes les plateformes.Pour répondre à ce problème, un développeur a créé reflaxe.lua, un transpilateur personnalisé exploitant l'architecture de macros Haxe. Il convertit le code Haxe en Lua 5.1 pur, en mappant directement les objets et tableaux Haxe sur les tables Lua natives, réduisant le surcoût matériel à zéro.Exemples CraftGoldHaxe possède de véritables Types Algébriques de Données (ADT) via les "Enum", offrant un pattern matching exhaustif avec des extracteurs (extractors) qui permettent de transformer la donnée à la volée.Haxe// Les Enums Haxe sont de vrais ADTs (Generalized Algebraic Data Types)
enum Method {
    Buy(cost: Int, craftCost: Null<Int>);
    Craft(cost: Int, buyPrice: Null<Int>);
}

class Calculator {
    static public function calculate(ctx: IWoWContext, itemID: Int, qty: Int, state: Map<Int, Bool>): Null<Method> {
        if (state.exists(itemID)) return null;
        state.set(itemID, true);

        // ... logique de calcul similaire ...

        // Le compilateur vérifiera l'exhaustivité des types retournés
        return if (buyCost != null && craftCost != null) {
            buyCost <= craftCost ? Buy(buyCost, craftCost) : Craft(craftCost, buyCost);
        } else if (buyCost != null) {
            Buy(buyCost, null);
        } else if (craftCost != null) {
            Craft(craftCost, null);
        } else {
            null;
        }
    }
}
Limites et RisquesLe problème majeur de reflaxe.lua est son "Bus Factor". Maintenu par un seul contributeur, il s'agit d'un projet de niche (moins de 20 étoiles GitHub). Bien que le concept de mappage direct vers Lua soit techniquement brillant et surpasse TSTL sur la création d'ADT natifs, l'absence de soutien communautaire pour les définitions de l'API World of Warcraft exigera l'écriture manuelle de centaines de lignes d'externes (extern class).SourcesDocumentation Haxe Enums et Pattern Matching.Dépôt et architecture de reflaxe.lua.TealVue d'ensembleTeal n'est pas un langage foncièrement nouveau ; c'est un dialecte de Lua qui se contente d'ajouter des annotations de typage (comparable à ce que MyPy représente pour Python). Il compile directement vers du code Lua en effaçant simplement les annotations de types, ce qui garantit une intégration et des performances parfaites à 100% avec l'écosystème WoW 5.1.Limites face au problème poséTeal excelle dans la validation statique de tables Lua (via des records), le "Type Narrowing" des types d'union (number | string vérifié avec if x is string then), et empêche les erreurs d'inattention courantes. Plusieurs Addons WoW mineurs (LittleBuster, TomoMod) utilisent Teal avec succès.Toutefois, Teal ne résout pas la problématique de la complexité algorithmique de CraftGold.Il n'introduit aucun nouveau paradigme fonctionnel.Il ne dispose pas de Pattern Matching structurel.Il n'isole pas les effets de bord (le code reste purement impératif avec des mutations globales possibles).L'absence d'abstractions pour l'asynchronisme signifie que la machine à états Scanner.lua restera une cascade de callbacks difficile à maintenir.SourcesDocumentation officielle de Teal et Type Narrowing.Exemples d'implémentation dans WoW.Approches Alternatives et ExpérimentalesPour répondre à l'ambition de cette recherche, plusieurs autres pistes ont été évaluées mais écartées pour des raisons techniques invalidantes :Amulet : Le candidat OCaml-like parfait sur le papier (types algébriques, polymorphismes de haut rang, compilation vers un module Lua propre). Malheureusement, le projet est officiellement mort ("Amulet is no longer under development").Urn : Dialecte Lisp avec un excellent système de macros, mais dépassé par la simplicité et la communauté grandissante de Fennel. Il génère un code Lua moins idiomatique et s'appuie sur une bibliothèque standard personnalisée imposante, ce qui augmente le poids de l'add-on.Nelua : Orienté vers la programmation système avec gestion manuelle de la mémoire (style C). Le compilateur Nelua traduit d'abord le code vers du langage C natif, avant de (parfois) cibler d'autres plateformes. Il ne fournit pas les paradigmes fonctionnels requis.loo / lua_of_ocaml : Projets universitaires ou générés par l'IA traduisant le bytecode OCaml en Lua. Ces outils manquent cruellement d'une Foreign Function Interface (FFI) robuste, interdisant le dialogue avec les environnements complexes de World of Warcraft.DSL Haskell compilant vers Lua : Construire un compilateur source-to-source personnalisé en Haskell en s'appuyant sur l'AST language-lua. Bien que cette solution garantirait une isolation monadique parfaite des IO (via une Free Monad interprétée côté Lua), le coût d'ingénierie (création du compilateur, typage des APIs Blizzard, maintenance) est disproportionné par rapport à l'adoption d'un outil éprouvé comme TypeScriptToLua.Tableau Comparatif des Cibles(Évaluation notée de 1 [Inadapté] à 5 [Idéal])CritèrePureScript (pslua)TSTL (TypeScript)FennelHaxe (reflaxe.lua)TealMaturité / Pérennité2 (Backend alpha)5 (Support massif)5 (LÖVE, Neovim)2 (Mainteneur unique)4Paradigme Fonctionnel5 (Pur, Curry, ADT)4 (Via Immutabilité)4.5 (Lisp-1)42 (Limité)Séparation Logique / IO5 (Effets monadiques)4.5 (Injections)2 (Discipline)32Expressivité du Typage5 (HKT, Typeclasses)5 (Typage structurel)1 (N/A)4.5 (GADT)3Mocking API externe4.5 (Tagless Final)5 (Interfaces TS)444Qualité du Lua généré3 (GC / Upvalues)4.5 (Idiomatique)5 (Zéro overhead)45Optimisation (DCE, IR)4 (CoreFn DCE)4 (Plugin AST)1 (Pas d'IR)31Interopérabilité WoW3 (FFI stricte)5 (Typages existants)5 (Appels directs)45Expérience Développeur35 (NPM, TS LSP)4 (Fennel-LS)43Recommandation Finale pour CraftGoldPour résoudre les problématiques fondamentales de l'architecture de CraftGold au sein des contraintes impitoyables de la machine virtuelle World of Warcraft (Lua 5.1, limite de temps CPU, GC), la recommandation se porte sans équivoque sur TypeScriptToLua (TSTL), appliqué via les principes de l'architecture "Clean" fonctionnelle.Bien que PureScript représente le paroxysme de l'idéal théorique (garantissant formellement par le compilateur la séparation entre la logique pure de programmation dynamique de Calculator et l'effet Quote.quote), il pèche fatalement sur sa compilation cible. La structure de l'interpréteur Lua 5.1, avec sa limite d'allocation des fermetures (upvalues) et la lenteur relative de son Garbage Collector, tolère mal l'intense curryfication générée par pslua. Un algorithme récursif profond comme un arbre d'extension de composants (Bill of Materials) risque de s'effondrer sous ce surcoût matériel inévitable.À l'inverse, TypeScriptToLua permet de conserver un code généré "plat" et ultra-performant, respectueux du moteur vieillissant de WoW Classic.
En exploitant intelligemment le système de types de TypeScript :Les Unions Discriminées (kind: "buy" | "craft") remplaceront efficacement les ADT, assurant un pseudo-pattern matching statiquement exhaustif.L'utilisation d'Interfaces (IWoWContext) en injection de dépendances découplera de manière propre et élégante les effets de l'API de Blizzard, rendant la configuration des tests avec Jest immédiate et limpide.La traduction exceptionnelle de la construction async/await en un moteur de coroutines Lua intégré par TSTL transformera la fastidieuse machine à états asynchrone du Scanner de l'Hôtel de Ventes en un code linéaire, intuitif et sans douleur.Cette solution allie la rigueur mathématique relative requise par la logique du sac à dos (DP Knapsack), la validation formelle des bases de données par le compilateur, et l'accès à l'écosystème communautaire existant massif de définitions WoW pour TypeScript (wow-eluna-ts-module), assurant une migration rapide et sécurisée de CraftGold.