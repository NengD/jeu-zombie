extends RefCounted
## Textes partagés : liste des touches et guide du joueur.

const TOUCHES := [
	["Se déplacer", "Z Q S D"],
	["Sprinter", "Maj"],
	["Sauter", "Espace"],
	["S'accroupir (discret, surtout dans un buisson)", "C ou Ctrl"],
	["Se pencher à gauche / à droite", "A / E"],
	["Frapper / tirer", "Clic gauche"],
	["Coup puissant (arme de mêlée)", "Maintenir clic gauche"],
	["Viser (armes à feu) / parer (mêlée)", "Clic droit"],
	["Barre rapide (arme ou objet)", "1 à 5, molette"],
	["Recharger", "R"],
	["Se soigner", "H"],
	["Fouiller / utiliser", "F"],
	["Inventaire et fabrication", "Tab ou I"],
	["Carte", "M"],
	["Lampe torche / lampe de l'arme", "L"],
	["Inspecter l'arme (accessoires)", "T"],
	["Mode construction (marteau)", "B"],
	["Renforcer / réparer une pièce", "G"],
	["Démonter une pièce", "X"],
	["Personnage : niveaux et compétences", "K"],
	["Pause", "Échap"],
	["Sauvegarde rapide / chargement", "F5 / F9"],
	["Aide en jeu", "F1"],
]

const GUIDE := """[b]LES BASES[/b]
• Fouille les meubles (armoires, casiers, frigos…) et les corps des zombies avec [b]F[/b].
• Surveille ta faim et ta soif : si l'une tombe à zéro, tu perds de la santé.
• La santé remonte doucement tant que tu es bien nourri et hydraté.
• Ton inventaire de base fait 8×5 cases. Un gilet et un sac à dos ajoutent de la place en plus : trouve de plus grands sacs !

[b]COMBAT[/b]
• Les armes à feu font beaucoup de bruit et attirent les zombies de loin. Les armes blanches sont discrètes.
• Viser la tête inflige 2,5× plus de dégâts et ignore l'armure des zombies policiers et militaires.
• Recul selon l'arme : pistolet sec et court, fusil à pompe brutal, fusil d'assaut régulier (la visée se stabilise en rafale),
  fusil de précision gros coup unique. La visée revient ensuite doucement au centre ; baisser la souris compense plus vite.
• Accroupi, tu es plus difficile à repérer. Penche-toi (A / E) pour regarder au coin d'un mur.
• La nuit, les zombies voient moins bien… sauf si ta lampe est allumée. Certains courent plus vite.
• Chaque coup affiche ses [b]dégâts[/b] au-dessus de la cible (orange : tir à la tête, doré : coup critique) ;
  une petite [b]barre de vie[/b] apparaît au-dessus des ennemis touchés ou visés, puis s'efface.

[b]INVENTAIRE[/b]
• Chaque objet occupe des cases : une conserve 1×1, une batte 1×4, un sac 3×3…
• Glisse-dépose les objets entre tes poches, ton sac et les meubles fouillés. [b]R[/b] pendant le glissement pour tourner un objet.
• Double-clic : utiliser / équiper. Ctrl + clic : transfert rapide. Clic droit : options (diviser une pile, jeter…).
• Lâcher un objet hors de la fenêtre le jette au sol (on peut le reprendre en fouillant le tas).
• Glisse un sac ou un gilet sur l'emplacement d'équipement pour l'équiper et profiter de son rangement.
• L'équipement porté se voit sur ton personnage : casque, bonnet ou casquette (Tête), masque à gaz ou lunettes (Visage), gilet ou veste (Torse), sac (Dos). Les armes de ta barre rapide que tu ne tiens pas sont rangées sur toi : fusil, arc ou arme longue dans le dos, pistolet à la cuisse, couteau à la hanche. Bandits et zombies portent aussi de l'équipement.
• [b]Trier par type / par poids[/b] (boutons en haut de l'inventaire) : tout se range et les piles se regroupent
  (les piles incomplètes se regroupent aussi à chaque ouverture).
• Conteneur ouvert : [b]Tout prendre[/b], ou [b]Déposer les matériaux[/b] pour vider d'un coup tes ressources de fabrication.
• [b]Charge[/b] : le poids porté s'affiche sous les jauges (et dans l'inventaire). Au-delà du seuil (22 kg + la moitié de
  la capacité du sac), tu ralentis ; à 1,5 fois le seuil, plus de sprint.
• Au survol : poids, prix de revente chez un marchand, et [b]comparaison[/b] avec l'arme en main (dégâts, cadence,
  dispersion, recul, chargeur…) ou la pièce d'équipement portée (protection, rangement).
• Munitions et flèches sont [b]ramassées automatiquement[/b] en passant dessus (flèches plantées, tas au sol des bandits) ;
  l'option se coupe dans les Paramètres. Ce que tu jettes toi-même n'est pas repris.
• Barre rapide : clic droit sur une case > [b]Verrouiller[/b] : l'objet garde sa place même quand tu n'en as plus
  (il y revient quand tu le reprends) et les nouvelles armes ne s'y rangent pas.

[b]ARMES À FEU[/b]
• 25 armes réelles : pistolets (Glock 19, MR920, M45A1, Desert Eagle), pistolets-mitrailleurs (MP5K, MP7), fusils à pompe (Benelli M4, TOZ-34), fusils d'assaut (M4A1, M5, URG-I, LR-300, MCX, AK-74, AK-74M, Draco), fusils 7.62 (UAR-10, Spear), fusils de précision (C14, L96, Gepárd, Mosin), Marlin à levier et mitrailleuse MG5.
• Chaque arme a son calibre (9 mm, .45, 5.56, 5.45, 7.62…). Les fusils à verrou se réarment à la main après chaque tir ; les balles des fusils de précision traversent plusieurs zombies.
• [b]T[/b] : inspecter l'arme et poser ses accessoires (viseurs point rouge et holographiques, lunettes ×4 à ×12, silencieux, freins de bouche, module laser-lampe, poignée verticale, chargeur grande capacité).
• Grenade RGD-5 : mets-la dans la barre rapide, clic gauche pour la dégoupiller et la lancer.
• Certains zombies policiers et militaires portent une arme : elle tombe au sol à leur mort.
• Modèles 3D des armes : D_U (Sketchfab), licence CC BY 4.0.

[b]MÉTÉO ET AMBIANCE[/b]
• Des averses passent de temps en temps : sols et murs mouillés qui brillent, flaques, ciel gris et brume.
  La pluie couvre les bruits : les zombies t'entendent moins loin.
• La nuit, les lampadaires des rues s'allument (certains clignotent, d'autres sont en panne).
• Herbe haute qui ondule au vent dans la campagne. Réglage « Qualité graphique » (Paramètres ou pause) :
  Bas, Moyen, Élevé, Ultra.

[b]BANDITS[/b] (camps en rouge sur la carte M)
• Des bandes armées campent hors des villes : tentes, brasero, sacs de sable. Ils patrouillent autour du camp,
  entendent les coups de feu et voient moins loin la nuit (sauf si ta lampe est allumée).
• Quand l'un d'eux te repère, tout le camp est alerté. Ils gardent leurs distances, se décalent et rechargent.
  Leurs tirs font du bruit et attirent les zombies… sur lesquels ils tirent aussi.
• Un bandit abattu lâche son arme, des munitions et un objet ; tu gagnes de l'argent et de l'XP.
  Les caisses des bandits contiennent un bon butin (munitions, soins, parfois une arme ou une grenade).
• Les zombies s'en prennent aussi aux bandits ; un bandit grièvement blessé court se mettre à l'abri derrière
  les sacs de sable ou une épave, et tire de là.
• [b]Primes[/b] : chaque marchand indique où sont les camps et paie une prime (80 € + 30 € par bandit)
  quand un camp est entièrement nettoyé. Viens la toucher chez un marchand.
• Décor des camps (brasero, caisse de munitions, jerrican, lanterne) et textures du monde : Poly Haven, licence CC0.
• Personnages low-poly : « Ultimate Modular Men / Women » de Quaternius, licence CC0.
• Cerf et biche : « Ultimate Animated Animal Pack » de Quaternius, licence CC0.
• Train, tentes et tours de garde : Quaternius (CC0) ; petit avion : Vojtěch Balák ; hélicoptère : Zsky ; bulldozer et bus scolaire : Poly by Google ; camion militaire : Alex Safayan (CC BY 3.0, via Poly Pizza).
• Équipement porté : sacs (Quaternius, Voxel_dev, accidentallyc), lunettes (iPoly3D) — CC0 ; casque intégral (CreativeTechLab), casque de chantier (Poly by Google), masque à gaz (Marisha), sac de chasse, bonnet et casquette (J-Toastie), casquette de police (Casey Tumbers) — CC BY 3.0, via Poly Pizza ; casque militaire (hc, OpenGameArt, CC BY 3.0).
• Voix des zombies : « Zombies Sound Pack » d'artisticdude et « Zombie noises and moans » d'ianzazz (OpenGameArt), licence CC0.

[b]NIVEAUX ET COMPÉTENCES[/b] (touche K)
• Chaque action rapporte de l'XP : tuer des zombies (Combat), fabriquer et construire (Fabrication), fouiller et découvrir des bâtiments (Exploration), manger, boire, se soigner et encaisser des coups (Survie).
• Niveau global : +1 point d'attribut à placer en Endurance, Santé, Soif ou Faim.
• Chaque niveau de compétence donne 1 point de talent : débloque des bonus (dégâts, recharge, soins, munitions, discrétion, poches plus grandes…).

[b]BARRE RAPIDE[/b]
• Dans l'inventaire, glisse un objet sur un emplacement 1 à 5 de la barre rapide.
• Clic droit sur un emplacement pour le vider.
• Une arme dans un emplacement se prend en main ; un consommable (bandage, eau…) s'utilise directement.

[b]FABRICATION[/b] (Tab, onglet Fabrication)
• Les recettes sont rangées par catégorie : outils et matériaux, armes, munitions, soins, nourriture, vêtements, construction.
• Ingrédients que tu as en vert, ceux qui manquent en rouge. Chaque recette demande une station, un niveau de fabrication
  et un temps (plus court quand le niveau monte). Fabrique ×1, ×5 ou le maximum ; la barre montre la progression
  (tu peux marcher pendant ce temps, mais un coup reçu ou une station trop loin interrompt la série).
• Stations à fabriquer et à poser : établi, [b]feu de camp[/b] (2 planches + 1 tissu, se pose dehors ; les braseros des camps
  servent aussi) et [b]plan de couture[/b] (3 planches + 4 clous + 2 tissus). [F] sur une station ouvre la fabrication.
• [b]Démonter[/b] (clic droit sur l'objet > Démonter, ou bouton sous la recette) : rend environ la moitié des ingrédients
  de sa recette la moins chère (une demi-unité = une chance sur deux), à la même station, par lot de fabrication
  (ex. 5 flèches). Pas la nourriture ni les matériaux (planche, ferraille, cuir, ciment) ; un sac doit être vide.
• Les ingrédients sont aussi pris dans les [b]caisses de stockage de ta base[/b] à moins de 12 m (« tu as 2 + 5 dans les caisses ») :
  pas besoin de tout porter.
• [b]Favoris[/b] : « Épingler en favori » sous une recette la met en haut de la liste, avec ce qu'il manque.
• Recettes [b]de fortune[/b], à la main : bandage, flèches taillées (1 planche → 2 flèches), [b]torche[/b] à planter
  (planche + tissu + alcool, ou bûche + tissu + graisse) qui éclaire la nuit.

[b]ARC ET CHASSE[/b]
• Arc (fermes, camping, ou établi : 2 planches + 1 cuir + 2 tissus). Maintiens le clic gauche pour bander, relâche pour tirer :
  plus la corde est tendue, plus la flèche va loin et fait mal. Clic droit : lever l'arc et viser. Les traits sous le viseur
  montrent où tombe la flèche à 20, 40 et 60 m. Presque silencieux.
• Discrétion : un zombie tué d'une flèche sans t'avoir vu tombe sans alerter ses voisins ; s'il n'est que blessé,
  il part voir d'où vient le tir (sans encore savoir où tu es).
• Flèches : 1 planche + 2 plumes (ou 1 tissu) + 1 ferraille, ou 1 os pour la pointe. Plantées dans le décor, on les ramasse
  souvent ([F]) ; dans un animal ou un zombie, on les retrouve parfois en dépeçant ou en fouillant le corps.
• Animaux : cerfs, biches et sangliers en forêt, faisans et lapins dans les champs. Ils entendent les bruits et te voient de loin :
  approche accroupi, caché dans les buissons. Le sanglier peut charger !
• Animal mort : [F] pour le dépecer avec un couteau, une machette ou une hache (viande crue, peau, os, graisse, plumes).
• Collets à lapins (1 ferraille + 1 planche → 2) : à poser dehors loin des villes ; un lapin s'y prend si personne ne rôde autour.

[b]RÉCOLTE : HACHE ET PIOCHE[/b]
• Frappe le décor avec l'outil en main (clic gauche, plusieurs coups) : la [b]hache[/b] abat les arbres (2 à 5 bûches,
  il reste une souche), la [b]pioche[/b] brise les rochers (pierres, parfois du minerai de fer ou de la ferraille), et
  les deux démontent les [b]épaves de voitures[/b] (ferraille, pièces auto, pneu, batterie, essence, tissu ; l'épave vidée noircit).
• Rendement selon la compétence (écran Personnage, K) : par niveau, 4 % de coups en moins et 6 % de ressources en plus
  (niveau 10 : -40 % de coups, +60 % de ressources) ; [b]Survie[/b] pour les arbres et rochers, [b]Fabrication[/b] pour les épaves.
• Les coups font du bruit (les zombies viennent voir). Rien ne repousse, mais il y a des milliers d'arbres et de rochers.
• Bûche → 3 planches à l'établi (1 seule à la main) ; minerai + bûche → ferraille au feu ; 4 pierres + eau → ciment (établi) ;
  feu de camp en pierres et bûches ; barricade de pneus ; projecteur sur batterie ; flèches à pointe de pierre.
• La pioche (quincaillerie, fermes, granges, ou établi : 4 ferrailles + 1 bûche + 1 ruban) est aussi une arme lourde.

[b]CUISINE ET MALADIE[/b]
• Au feu de camp ou au brasero : viande cuite, bouillon d'os, ragoût de chasse ; tannage (2 peaux + 1 graisse → 1 cuir).
• Au plan de couture : veste et capuche de cuir, sac de chasse, sac à dos.
• Manger de la viande crue peut rendre malade (intoxication) : faim et soif baissent vite, endurance réduite, nausées.
  Ça passe avec le temps, ou tout de suite avec des médicaments anti-nausée (pharmacies, hôpitaux).

[b]CONSTRUIRE SA BASE[/b]
1. Fabrique un établi (Tab) : 4 planches + 6 clous + 2 ferrailles.
2. Vide un bâtiment de tous ses zombies : le coin en haut à droite affiche « bâtiment sûr ».
3. Dans l'inventaire, sélectionne l'établi puis « Utiliser » : un fantôme vert apparaît.
   Clic gauche pour poser, molette ou R pour tourner, clic droit pour annuler.
4. Près de l'établi, ses recettes se débloquent : munitions, armes, caisse de stockage… (voir FABRICATION).
5. Les barricades se posent n'importe où, par exemple dans une porte. Les zombies peuvent les casser.

[b]CONSTRUIRE TA PROPRE MAISON[/b] (marteau : 2 ferrailles + 1 planche)
• Touche B : mode construction. Molette = pièce, clic gauche = poser, R = tourner l'escalier, B ou clic droit = quitter.
• Commence par une fondation sur un terrain plat, puis ajoute fondations, murs, encadrement de porte + porte,
  murs à fenêtre, demi-murs, planchers (posés sur les murs : ils font le plafond et l'étage) et escaliers.
• Les pièces s'aimantent sur une grille de 3 m. Fantôme vert = possible ; rouge = la raison s'affiche.
• [G] sur une pièce : la réparer, ou la renforcer bois → tôle (ferraille) → parpaing (sacs de ciment).
• [b]Maj + G[/b] : réparer toute la base d'un coup (pièces, pièges et barricades), ou si rien n'est abîmé, la renforcer
  entièrement d'un niveau. Le coût total s'affiche en visant une pièce.
• [b]Lit de camp[/b] (établi : 4 planches, 4 clous, 4 tissus), à poser dans la base : [F] la nuit pour dormir jusqu'à 7 h.
  Refusé si un zombie ou un bandit est à moins de 30 m ; faim et soif baissent pendant le sommeil (deux fois moins vite).
• [X] démonte une pièce et rend la moitié du bois. Les zombies tapent dans les murs qui leur barrent la route.
• L'établi et la caisse de stockage se posent aussi sur les planchers de ta base.
• [b]Pièges[/b] (à placer dehors, depuis l'inventaire) : piques en bois (3 planches + 2 clous) qui blessent les zombies
  qui les traversent, barbelés (4 ferrailles + 2 clous, établi) qui les ralentissent fortement. Ils s'usent à chaque zombie :
  en mode construction (B), vise-les et appuie sur G pour les réparer (les barricades aussi).
• [b]Hordes[/b] : à partir du 2e jour, à la tombée de la nuit, une horde peut marcher sur ta base (au moins 4 pièces).
  Une alerte s'affiche 60 secondes avant son arrivée et dit de quel côté elle vient (on l'entend grogner de ce côté) : rentre et prépare-toi ! Si tu es loin,
  elle abîme tes murs ; les pièges autour de la base réduisent les dégâts.

[b]PROJECTEURS[/b] (3 ferrailles + 1 ruban + 1 tissu, établi — ou chez le quincaillier)
• À poser dehors autour de ta base pour voir venir les zombies la nuit. [F] : automatique (s'allume la nuit) / allumé / éteint.

[b]ARGENT ET MARCHANDS[/b]
• Les meubles et caisses proches qui ont encore quelque chose à prendre brillent d'un liseré doré.
• Soins : antidouleurs (0,5 s, +10), bandage (0,9 s, +15), trousse (3,5 s, santé au maximum, interrompue si tu es touché). On marche lentement pendant un soin. [H] choisit le soin adapté à ta blessure.
• Tu trouves des euros sur les zombies et dans les meubles fouillés. Ton argent s'affiche en haut à droite.
• Des [b]campements de marchands[/b] (points verts sur la carte, juste à la sortie des villes) : médecin, quincaillier
  et armurier près de Bellerive, médecin et armurier près de Valmont. Chacun est entouré d'une palissade et gardé par des survivants armés qui abattent les zombies :
  un vrai refuge. [F] devant un stand : acheter son stock, ou revendre tes objets à 40 % de leur prix.
• Les munitions se vendent et s'achètent par 20, les clous par 10 et les planches par 5.
• [b]Vendre tout le bric-à-brac[/b] (avec confirmation) : armes et vêtements en double, munitions qu'aucune de tes armes
  ne tire, matériaux qui ne servent à rien. Les cases verrouillées de la barre rapide sont épargnées.

[b]PARAMÈTRES[/b] (menu principal, ou Échap > Paramètres en pleine partie)
• Sensibilité de la souris et sensibilité en visée, champ de vision, taille du texte et de l'interface,
  ramassage automatique, volumes (général, effets, voix des zombies, ambiance), qualité graphique.
• Touches : clic sur une touche puis appuie sur la nouvelle (clavier ou souris) ; « Touches par défaut » pour tout remettre.
• Tout s'applique tout de suite et est enregistré en revenant (Retour ou Échap).

[b]S'ORIENTER[/b]
• [b]Boussole[/b] en haut de l'écran : directions, tes marqueurs, le campement de marchands le plus proche et les lieux
  à moins de 300 m, avec la distance.
• Carte (M) : [b]clic droit[/b] pour poser un marqueur nommé (Entrée pour valider), clic droit dessus pour le retirer.
  Les lieux dont presque tout a été fouillé sont [b]grisés[/b]. En bas : distance et direction des marchands les plus proches.

[b]POINTS STRATÉGIQUES[/b] (touche M pour la carte)
• [b]Lieu de départ[/b] : à chaque nouvelle partie, tu choisis où commencer — hameau ou village (facile : peu de zombies),
  ferme isolée ou maison de Bellerive (moyen), lotissement ou centre de Valmont (difficile), centre-ville ou base militaire
  (extrême : foule de zombies, meilleur butin), ou au hasard. Le message d'arrivée résume les zombies, le butin et la distance des marchands.
• La région fait 5 × 5 km : [b]Bellerive[/b] (ville principale), [b]Valmont[/b] (au nord-est, avec sa zone industrielle),
  quatre villages (Saint-Aubin, Hameau des Sources, les Granges, Pont-Rouge), fermes, stations-service, motels.
  Sur la carte : molette pour zoomer, clic maintenu pour la déplacer, [Espace] pour recentrer sur toi
  (les boutiques et bâtiments des villes ne sont nommés qu'en zoomant fort) ; [L] affiche ou masque la légende.
  Ta base (ta plus grande construction) apparaît en maison bleue « Ma base » sur la carte et la boussole.
• Les villes ont un [b]centre dense[/b] (immeubles hauts, bureaux) et des [b]quartiers pavillonnaires[/b] sur le pourtour ;
  chacune a un [b]lotissement neuf[/b] en périphérie (des Tilleuls, du Moulin-Neuf) : maisons identiques, vite fouillées.
• En ville : [b]centre commercial[/b] (six boutiques autour d'une galerie), [b]pharmacie[/b] (soins), [b]garage auto[/b]
  (ferraille, pièces auto, jerricans d'essence, clés à molette, ruban), [b]bibliothèque[/b] (fournitures de bureau),
  [b]bar-restaurant[/b] (alcool, boissons, nourriture, un peu d'argent dans la caisse), [b]église[/b]. Les boutiques ont une enseigne.
  Les [b]pièces auto[/b] se démontent en ferraille (artisanat).
• À la campagne : [b]scierie[/b] (outils, planches), [b]camping des Pins[/b] (caravanes et tentes fouillables),
  [b]relais routier[/b] (remorques de camions pleines de marchandises), [b]châteaux d'eau[/b] et silos des fermes, visibles de loin.
• [b]Châteaux d'eau[/b] : une échelle mène à la coursive (22 m), point de vue pour repérer les environs, hors d'atteinte des zombies.
  Face à l'échelle, [Z] monte, [S] descend ; en haut, [Z] fait passer sur la coursive ; [Espace] lâche l'échelle (attention à la chute).
• [b]Routes secondaires[/b] : elles quadrillent la campagne ; aux carrefours, un panneau indique les villes et villages proches
  (direction et distance), parfois un abribus. Des [b]barrages routiers[/b] abandonnés gardent une caisse de la police… et des policiers zombies.
• [b]Voie ferrée[/b] au nord (gare de Valmont, halte des Granges) : wagons de marchandises à fouiller ; le [b]train déraillé[/b]
  (zone infestée, en rouge) transporte du matériel militaire et un wagon blindé au butin rare.
• [b]Forêts[/b] nommées sur la carte, plus denses (gibier) : cabanes de chasseur (munitions de chasse, arcs, flèches) et
  miradors (échelle, caisse en haut), reliés à la route par un sentier. Fermes et maisons isolées le long des routes ;
  lignes à haute tension et parcs éoliens sur les collines, repères visibles de loin.
• [b]Lieux uniques[/b] (carte M) : [b]aérodrome[/b] (hangars, tour de contrôle avec échelle, soute du petit avion),
  [b]camp de réfugiés[/b] militaire (zone infestée : tentes, infirmerie, caisses humanitaires et militaires aux check-points),
  [b]crash d'hélicoptère[/b] en forêt (butin militaire rare), [b]casse auto[/b] (épaves à démonter, pièces détachées),
  [b]prison[/b] (nombreux zombies, armurerie des surveillants), [b]barrage et centrale[/b] sur un lac, [b]manoir en ruine[/b]
  et cimetière (caveau de famille), [b]colonie de vacances[/b] au bord d'un lac, [b]décharge[/b] (ferraille).
• [b]Nature[/b] : vergers, vignobles (domaine viticole : alcool), [b]champs de maïs[/b] hauts où l'on se cache comme dans un buisson,
  [b]marais[/b] près de la rivière (roseaux pour se cacher, zombies noyés), [b]carrière de pierre[/b] (gros rochers : pierre et minerai
  à la pioche) et la [b]grotte des Contrebandiers[/b] (cache d'armes). Épaves dans les fossés (à démonter), feux de camp abandonnés
  (sac et tente à fouiller). Les [b]cachettes de survivants[/b] ne sont pas sur la carte : cherche les bâches sous les arbres en forêt (très bon butin).
  Les [b]nids de zombies[/b] sont des zones infestées marquées en rouge sur la carte.
• [b]Poste de police[/b] : pistolets, MP5K, Benelli, munitions, gilets pare-balles.
• [b]Base militaire[/b] : fusils d'assaut, fusils de précision, grenades, gilet tactique, casque — très gardée ! Portail à l'est… et une brèche quelque part au nord.
• [b]Hôpital[/b] : bandages, trousses de soin, antidouleurs.
• [b]Supermarché[/b] : nourriture et boissons.
• [b]Armurerie[/b] : armes et munitions.
• [b]Quincaillerie[/b] : planches, clous, ferraille, haches.
• [b]Fermes et station-service[/b] : matériaux, nourriture, cuir.
• [b]Villages[/b] (Saint-Aubin au nord, Hameau des Sources à l'ouest) : maisons à toit de tuiles, épicerie, mairie, église.
• [b]Carambolages[/b] (repères rouges) : zones infestées sur l'autoroute, une trentaine de zombies et des coffres bien remplis.
• [b]Grotte du Colosse[/b] (repère violet) : le BOSS, un zombie géant de 2 500 PV qui charge et frappe le sol. Prends une lampe ! Sa cache contient le meilleur butin du jeu.

[b]MODE ADMIN[/b] (bouton dans le menu principal, rien n'est sauvegardé)
• N : voler (Espace monte, Ctrl descend, Maj rapide). F2 : panneau admin (tous les objets, téléportation, heure, zombies, boss, niveaux).

[b]PAYSAGE[/b]
• Collines, lacs et rivière au nord de la ville (on peut marcher dans l'eau, lentement). Un pont la traverse sur l'autoroute.
• Cabane de pêche au bord de l'étang, antenne relais sur le point le plus haut. La carte (M) montre le relief et l'eau.

[b]CORPS À CORPS[/b]
• Armes de mêlée : coup vers l'avant ; battes et machette alternent avec un balayage latéral. Les armes lourdes frappent plus lentement mais repoussent le zombie. Maintenir le clic : coup puissant. Clic droit : parade (80 % de dégâts en moins, repousse le zombie).

[b]COUPS DE GRÂCE[/b]
• Un gros coup peut renverser un zombie. Près d'un zombie à terre ou d'un rampant : [F] Achever : coup de talon à mains nues, arme abattue (hache, batte) ou lame plantée (couteau, machette, matraque), ou balle à bout portant avec une arme chargée (+10 XP). Le geste dure une demi-seconde.

[b]ZOMBIES[/b]
• Coureurs, gros zombies, rampants. Bras et jambes peuvent être arrachés ; sans jambes, le zombie rampe.

[b]VISÉE ET RECHARGEMENT[/b]
• Le réticule s'écarte selon la précision réelle (hanche, visée, déplacement, rafale) et devient rouge sur un ennemi. Une croix orange montre où la balle s'arrêtera si un obstacle coupe la ligne de tir.
• Rechargement réaliste : le vrai chargeur sort de l'arme ; à vide, il tombe au sol et on réarme. Fusils à pompe, Mosin et Marlin : une cartouche à la fois.

[b]BÂTIMENTS ET PORTES[/b]
• Toutes les portes s'ouvrent et se ferment avec F. Les zombies ne savent pas les ouvrir : ils tapent dedans jusqu'à les enfoncer.
• Les immeubles se visitent en entier : un escalier relie tous les étages, chacun avec ses meubles… et ses habitants."""


static func touches_texte() -> String:
	var lines: PackedStringArray = []
	for t in TOUCHES:
		lines.append("%s : %s" % [t[1], t[0]])
	lines.append("(Touches par défaut : elles se changent dans Paramètres, au menu principal ou dans le menu pause.)")
	return "\n".join(lines)
