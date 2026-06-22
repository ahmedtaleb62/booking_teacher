// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Sawelni';

  @override
  String get splashTagline => 'Plateforme de cours particuliers en direct';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonSend => 'Envoyer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonCopied => 'Copié';

  @override
  String get commonLoading => 'Chargement...';

  @override
  String get commonError => 'Une erreur s\'est produite';

  @override
  String get commonErrorNetwork =>
      'Connexion impossible, vérifiez votre réseau';

  @override
  String get commonErrorLoading => 'Échec du chargement';

  @override
  String get commonNoData => 'Aucune donnée';

  @override
  String get commonYes => 'Oui';

  @override
  String get commonNo => 'Non';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get authWelcome => 'Bienvenue';

  @override
  String get authLoginSubtitle => 'Connectez-vous pour continuer';

  @override
  String get authEmail => 'Adresse e-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authLoginBtn => 'Se connecter';

  @override
  String get authNoAccount => 'Pas encore de compte ?  ';

  @override
  String get authCreateAccount => 'Créer un compte';

  @override
  String get authRegisterTitle => 'Créer un compte';

  @override
  String get authRegisterSubtitle => 'Rejoignez la plateforme Sawelni';

  @override
  String get authAccountType => 'Type de compte';

  @override
  String get authStudent => 'Étudiant';

  @override
  String get authTeacher => 'Professeur';

  @override
  String get authFullName => 'Nom complet';

  @override
  String get authFullNameHint => 'Mohamed Ahmed';

  @override
  String get authRegisterBtn => 'Créer le compte';

  @override
  String get authHaveAccount => 'Vous avez déjà un compte ?  ';

  @override
  String get authLoginLink => 'Se connecter';

  @override
  String get authValidEmail => 'Entrez votre adresse e-mail';

  @override
  String get authValidEmailFormat => 'Adresse e-mail invalide';

  @override
  String get authValidPassword =>
      'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get authValidName => 'Entrez votre nom complet';

  @override
  String get authErrInvalidCredentials => 'E-mail ou mot de passe incorrect';

  @override
  String get authErrEmailNotConfirmed =>
      'E-mail non confirmé, vérifiez votre boîte de réception';

  @override
  String get authErrUserNotFound => 'Aucun compte associé à cet e-mail';

  @override
  String get authErrRateLimit =>
      'Trop de tentatives, réessayez dans quelques instants';

  @override
  String get authErrNetwork =>
      'Connexion au serveur impossible, vérifiez votre réseau';

  @override
  String get authErrServer => 'Erreur serveur, réessayez plus tard';

  @override
  String get authErrGeneral => 'Une erreur s\'est produite, réessayez';

  @override
  String get authErrEmailExists =>
      'Cet e-mail est déjà utilisé, connectez-vous';

  @override
  String get authErrEmailFormat => 'Format d\'e-mail invalide';

  @override
  String get authErrUnexpected => 'Erreur inattendue, réessayez';

  @override
  String get authErrCheckEmail =>
      'Vérifiez votre e-mail pour confirmer le compte';

  @override
  String get homeTitle => 'Découvrir les professeurs';

  @override
  String get homeSearchHint => 'Rechercher une matière ou un professeur...';

  @override
  String get homeAllSubjects => 'Toutes les matières';

  @override
  String get homeNoTeachers => 'Aucun professeur disponible pour le moment';

  @override
  String get homeAvailableNow => 'Disponible maintenant';

  @override
  String get sessionsTitle => 'Mes sessions';

  @override
  String get sessionsTabActive => 'En cours';

  @override
  String get sessionsTabPending => 'En attente';

  @override
  String get sessionsTabEnded => 'Terminées';

  @override
  String get sessionsEmpty => 'Aucune session ici';

  @override
  String get sessionsEmptyHint =>
      'Trouvez un professeur et commencez votre parcours';

  @override
  String get sessionsEnterNow => 'Rejoindre la session';

  @override
  String get sessionsCompletePayment => 'Finaliser le paiement';

  @override
  String get sessionsProofRejected => 'Preuve rejetée — renvoyez';

  @override
  String get sessionStatusTitle => 'Statut de la session';

  @override
  String get sessionNextStep => 'Prochaine étape';

  @override
  String get sessionResponsible => 'Responsable maintenant';

  @override
  String get sessionHistory => 'Historique';

  @override
  String get sessionSubject => 'Matière';

  @override
  String get sessionLevel => 'Niveau';

  @override
  String get sessionDate => 'Date';

  @override
  String get sessionDuration => 'Durée';

  @override
  String get sessionPrice => 'Prix';

  @override
  String sessionMinutes(int n) {
    return '$n min';
  }

  @override
  String sessionOugiya(String n) {
    return '$n MRU';
  }

  @override
  String get stateRequested => 'Demande envoyée';

  @override
  String get stateTeacherApproved => 'Professeur a accepté';

  @override
  String get stateTeacherRejected => 'Professeur a refusé';

  @override
  String get stateAwaitingPayment => 'En attente de paiement';

  @override
  String get statePaymentSubmitted => 'Preuve envoyée';

  @override
  String get statePaymentRejected => 'Preuve de paiement rejetée';

  @override
  String get statePaymentConfirmed => 'Paiement confirmé';

  @override
  String get stateConfirmedBooking => 'Réservation confirmée';

  @override
  String get stateActiveSession => 'Session en cours';

  @override
  String get stateCompleted => 'Terminée';

  @override
  String get stateTeacherNoShow => 'Absence du professeur';

  @override
  String get stateStudentNoShow => 'Absence de l\'étudiant';

  @override
  String get stateDispute => 'Litige en cours';

  @override
  String get stateCancelled => 'Annulée';

  @override
  String get subRequested => 'En attente de la réponse du professeur';

  @override
  String get subTeacherApproved =>
      'Vous pouvez maintenant effectuer le paiement';

  @override
  String get subTeacherRejected =>
      'Désolé, le professeur a refusé votre demande';

  @override
  String get subAwaitingPayment =>
      'Envoyez une preuve de paiement pour continuer';

  @override
  String get subPaymentSubmitted => 'L\'administration vérifie votre preuve';

  @override
  String get subPaymentRejected => 'Renvoyez une photo claire du virement';

  @override
  String get subPaymentConfirmed =>
      'L\'administration confirme votre réservation';

  @override
  String get subConfirmedBooking =>
      'Votre rendez-vous est réservé — préparez-vous !';

  @override
  String get subActiveSession => 'La session est en cours';

  @override
  String get subCompleted => 'Merci, bonne continuation !';

  @override
  String get subTeacherNoShow => 'Le montant sera remboursé ou reprogrammé';

  @override
  String get subStudentNoShow => 'Vos gains seront versés selon la politique';

  @override
  String get subDispute => 'L\'administration examine la situation';

  @override
  String get subCancelled => 'La session a été annulée';

  @override
  String get respTeacher => 'Professeur — Répondre à votre demande';

  @override
  String get respStudent => 'Vous — Effectuer le paiement';

  @override
  String get respAdmin => 'Administration — Vérification de la preuve';

  @override
  String get respAdminConfirm => 'Administration — Confirmation de la session';

  @override
  String get respBoth => 'Professeur & Étudiant — Rejoindre';

  @override
  String get respDone => 'Terminé';

  @override
  String get respNone => '—';

  @override
  String get nextWaitTeacher => 'Attendez la réponse du professeur';

  @override
  String get nextCompletePayment => 'Finaliser le paiement maintenant';

  @override
  String get nextWaitAdmin => 'Attendez la vérification';

  @override
  String get nextRetryPayment => 'Renvoyer la preuve';

  @override
  String get nextWaitAdminConfirm => 'Attendez la confirmation';

  @override
  String get nextEnterSession => 'Rejoindre la session';

  @override
  String get nextRateTeacher => 'Évaluer le professeur';

  @override
  String get nextRated => 'Terminée ✓';

  @override
  String get nextFindTeacher => 'Trouver un autre professeur';

  @override
  String get nextReschedule => 'Reprogrammer la session';

  @override
  String get nextWaitDecision => 'Attendez la décision de l\'administration';

  @override
  String get actionCancelRequest => 'Annuler la demande';

  @override
  String get actionCompletePayment => 'Effectuer le paiement';

  @override
  String get actionRetryPayment => 'Renvoyer la preuve de paiement';

  @override
  String get actionEnterSession => 'Rejoindre la session';

  @override
  String get actionEnterIn10 => 'Accès disponible 10 min avant';

  @override
  String get actionRateTeacher => 'Évaluer le professeur';

  @override
  String get actionReschedule => 'Reprogrammer la session';

  @override
  String get actionFindTeacher => 'Trouver un autre professeur';

  @override
  String get actionThankRating => 'Merci pour votre évaluation 🌟';

  @override
  String get dialogCancelTitle => 'Annuler la demande';

  @override
  String get dialogCancelContent =>
      'Voulez-vous annuler cette demande ? Cette action est irréversible.';

  @override
  String get dialogCancelConfirm => 'Oui, annuler';

  @override
  String get dialogBack => 'Retour';

  @override
  String get dialogRatingTitle => 'Évaluer le professeur';

  @override
  String get dialogRatingCommentHint =>
      'Partagez votre expérience avec le professeur...';

  @override
  String get dialogRatingSend => 'Envoyer l\'évaluation';

  @override
  String get paymentTitle => 'Paiement';

  @override
  String get paymentProofSentTitle => 'Preuve de paiement envoyée';

  @override
  String get paymentProofSentBody =>
      'L\'administration vérifiera votre preuve dans l\'heure et confirmera la réservation.';

  @override
  String get paymentAwaitingInstruction =>
      'Envoyez le montant via l\'un des moyens de paiement ci-dessous, puis téléchargez une preuve de paiement.';

  @override
  String get paymentAmountLabel => 'Montant requis';

  @override
  String get paymentChooseMethod => 'Choisissez un mode de paiement';

  @override
  String get paymentAccountName => 'Nom du bénéficiaire';

  @override
  String get paymentHolder => 'Portefeuille / Numéro';

  @override
  String get paymentProofSection => 'Preuve de paiement';

  @override
  String get paymentProofHint => 'Téléchargez une capture du virement';

  @override
  String get paymentProofHintSub => 'PNG · JPG jusqu\'à 5 Mo';

  @override
  String get paymentWarning =>
      'Ne payez qu\'aux numéros affichés ci-dessus. N\'envoyez pas d\'argent à un autre numéro.';

  @override
  String get paymentSubmitBtn => 'J\'ai payé — Confirmer';

  @override
  String get paymentErrNoProof => 'Téléchargez d\'abord une preuve de paiement';

  @override
  String get paymentRejectedBanner =>
      'Preuve rejetée — renvoyez une photo claire du virement';

  @override
  String get paymentDeadlineExpired => 'Délai de paiement expiré';

  @override
  String get liveConnectError => 'Connexion impossible';

  @override
  String get liveWaitingTeacher =>
      'En attente du professeur pour démarrer la session…';

  @override
  String get liveOver15min => 'Plus de 15 min — le professeur n\'a pas démarré';

  @override
  String get liveReportNoShow => 'Signaler l\'absence du professeur';

  @override
  String get liveRescheduleHint =>
      'Vous pouvez reprogrammer avec le même montant payé';

  @override
  String get liveLeave => 'Quitter';

  @override
  String get liveLeaveTitle => 'Quitter la session';

  @override
  String get liveLeaveContent =>
      'Voulez-vous quitter la session ? Vous pouvez revenir plus tard.';

  @override
  String get liveLeaveConfirm => 'Quitter';

  @override
  String get liveNoShowTitle => 'Signaler l\'absence du professeur';

  @override
  String get liveNoShowContent =>
      'L\'absence du professeur sera enregistrée et vous pourrez reprogrammer. Continuer ?';

  @override
  String get liveConfirmNoShow => 'Confirmer l\'absence';

  @override
  String get liveSessionNotFound => 'Session introuvable';

  @override
  String get teacherDashboardTitle => 'Tableau de bord';

  @override
  String get teacherRequestsTitle => 'Demandes';

  @override
  String get teacherSessionsTitle => 'Sessions';

  @override
  String get teacherEarningsTitle => 'Revenus';

  @override
  String get teacherNotifTitle => 'Notifications';

  @override
  String get teacherProfileTitle => 'Mon profil';

  @override
  String get teacherReviewRequestTitle => 'Réviser la demande';

  @override
  String get teacherAvailableToggle => 'Statut';

  @override
  String get teacherAvailable => 'Disponible';

  @override
  String get teacherUnavailable => 'Indisponible';

  @override
  String get teacherResponseTime => 'Répondez de préférence dans les 24h';

  @override
  String get teacherTodaySessions => 'Sessions du jour';

  @override
  String get teacherPendingRequests => 'Demandes en attente';

  @override
  String get teacherWeekEarnings => 'Gains de la semaine';

  @override
  String get teacherTotalBalance => 'Solde total';

  @override
  String get teacherTabToday => 'Aujourd\'hui';

  @override
  String get teacherTabUpcoming => 'À venir';

  @override
  String get teacherTabCompleted => 'Terminées';

  @override
  String get teacherNoSessions => 'Aucune session';

  @override
  String get teacherNoRequests => 'Aucune nouvelle demande';

  @override
  String get teacherActiveNow => 'En cours maintenant';

  @override
  String get teacherBackToSession => 'Retourner à la session';

  @override
  String get teacherNoPending => 'Aucune demande en attente';

  @override
  String get teacherEnterSession => 'Rejoindre la session';

  @override
  String get teacherRejectBtn => 'Refuser la demande';

  @override
  String get teacherApproveBtn => 'Accepter la demande';

  @override
  String get teacherRejectDialogTitle => 'Refuser la demande';

  @override
  String get teacherRejectDialogBody => 'L\'étudiant sera notifié du refus.';

  @override
  String get teacherRejectReasonHint => 'Raison du refus (optionnel)';

  @override
  String get teacherNetEarning => 'Votre gain net';

  @override
  String teacherCommissionNote(String total) {
    return 'sur $total − 15% commission';
  }

  @override
  String get teacherStillPending => 'Vous — Répondre dans les 24h';

  @override
  String get teacherNowResponsible => 'Responsable maintenant';

  @override
  String get teacherRequestProcessed => 'Cette demande a été traitée';

  @override
  String get teacherRequestRejected => 'Cette demande a été refusée';

  @override
  String get teacherRequestCancelledByStudent =>
      'La session a été annulée par l\'étudiant';

  @override
  String get teacherSubjectLabel => 'Matière';

  @override
  String get teacherLevelLabel => 'Niveau scolaire';

  @override
  String get teacherDateLabel => 'Date demandée';

  @override
  String get teacherDurationLabel => 'Durée';

  @override
  String get teacherStudentNote => 'Description de la demande';

  @override
  String get teacherStudentLabel => 'Étudiant';

  @override
  String get teacherEarningsBalance => 'Solde accumulé';

  @override
  String get teacherEarningsWithdraw => 'Retirer les gains';

  @override
  String get teacherEarningsWithdrawContact =>
      'Pour retirer, contactez l\'administration : 42740370';

  @override
  String get teacherEarningsWeek => 'Cette semaine';

  @override
  String get teacherEarningsMonth => 'Ce mois';

  @override
  String get teacherEarningsFromSessions => 'Depuis les sessions';

  @override
  String get teacherEarningsFromCourses => 'Depuis les abonnements';

  @override
  String get teacherLedgerTitle => 'Historique des paiements';

  @override
  String get teacherLedgerEmpty => 'Aucune transaction pour le moment';

  @override
  String get teacherLedgerPayout => 'Règlement — gains versés';

  @override
  String get teacherStatusRequested => 'Nouvelle demande';

  @override
  String get teacherStatusApproved => 'Demande acceptée';

  @override
  String get teacherStatusRejected => 'Demande refusée';

  @override
  String get teacherStatusPaymentSubmitted =>
      'Preuve de paiement en cours de vérification';

  @override
  String get teacherStatusPaymentConfirmed =>
      'Paiement confirmé — réservation établie';

  @override
  String get teacherStatusConfirmedBooking => 'Session confirmée';

  @override
  String get teacherStatusActive => 'Session en cours maintenant';

  @override
  String get teacherStatusCompleted => 'Session terminée';

  @override
  String get teacherStatusNoShow => 'Votre absence a été enregistrée';

  @override
  String get teacherStatusStudentNoShow =>
      'L\'étudiant était absent. Vos gains seront versés selon la politique.';

  @override
  String get teacherStatusDispute =>
      'Cette session est en litige administratif';

  @override
  String get teacherStatusCancelled => 'L\'étudiant a annulé la session';

  @override
  String get teacherStatusProcessed => 'Cette session a été traitée';

  @override
  String get teacherEnterSessionBtn => 'Rejoindre la session';

  @override
  String get teacherSessionEntryNote =>
      'Accès disponible 10 min avant le rendez-vous';

  @override
  String get coursesMyCourses => 'Mes abonnements';

  @override
  String get coursesTabActive => 'Actifs';

  @override
  String get coursesTabPending => 'En attente';

  @override
  String get coursesTabExpired => 'Expirés';

  @override
  String get coursesEmpty => 'Aucun abonnement';

  @override
  String get coursesEmptyHint =>
      'Parcourez les cours et commencez votre apprentissage';

  @override
  String get coursesBrowse => 'Parcourir les cours';

  @override
  String get coursesProgress => 'Progression';

  @override
  String get coursesExpiry => 'Expire le';

  @override
  String get coursesResubscribe => 'Renouveler';

  @override
  String get coursesSubPending => 'En attente d\'approbation';

  @override
  String get coursesSubRejected => 'Refusé';

  @override
  String get courseLesson => 'leçon';

  @override
  String get courseLessons => 'leçons';

  @override
  String get profileTitle => 'Mon profil';

  @override
  String get profileEditProfile => 'Modifier le profil';

  @override
  String get profileChangePassword => 'Changer le mot de passe';

  @override
  String get profilePaymentHistory => 'Historique des paiements';

  @override
  String get profileMyRatings => 'Mes évaluations';

  @override
  String get profileHelpCenter => 'Centre d\'aide';

  @override
  String get profilePrivacyPolicy => 'Politique de confidentialité';

  @override
  String get profileTerms => 'Conditions générales';

  @override
  String get profileLogout => 'Se déconnecter';

  @override
  String get profileLogoutConfirm => 'Voulez-vous vous déconnecter ?';

  @override
  String get profileVersion => 'Version';

  @override
  String get notifTitle => 'Notifications';

  @override
  String get notifEmpty => 'Aucune notification';

  @override
  String get notifMarkAll => 'Tout marquer comme lu';

  @override
  String get notifTypeSessionRequested => 'Nouvelle demande de réservation';

  @override
  String get notifTypeTeacherApproved =>
      'Le professeur a accepté votre demande';

  @override
  String get notifTypeTeacherRejected => 'Votre demande a été refusée';

  @override
  String get notifTypePaymentRequired => 'Complétez le paiement';

  @override
  String get notifTypePaymentConfirmed => 'Paiement confirmé';

  @override
  String get notifTypeSessionConfirmed => 'Réservation confirmée';

  @override
  String get notifTypeSessionStarting => 'La session commence bientôt';

  @override
  String get notifTypeTeacherNoShow => 'Absence du professeur';

  @override
  String get notifTypeStudentNoShow => 'Absence de l\'étudiant';

  @override
  String get notifTypeSessionCompleted => 'Session terminée';

  @override
  String get notifTypeDisputeOpened => 'Litige ouvert';

  @override
  String get notifTypeRescheduled => 'Session reprogrammée';

  @override
  String get notifTypeSubPending => 'Abonnement en cours d\'examen';

  @override
  String get notifTypeSubActive => 'Abonnement activé';

  @override
  String get notifTypeSubRejected => 'Abonnement refusé';

  @override
  String get langArabic => 'العربية';

  @override
  String get langFrench => 'Français';

  @override
  String get langSwitcher => 'Langue';

  @override
  String get sessionNotFound => 'Session introuvable';

  @override
  String get sessionLoadError => 'Échec du chargement de la session';

  @override
  String get sessionListLoadError => 'Impossible de charger les sessions';

  @override
  String get notifLoadError => 'Impossible de charger les notifications';

  @override
  String get paymentRejectedTitle => 'Preuve de paiement rejetée';

  @override
  String get paymentFakeProofLabel =>
      'Preuve falsifiée — veuillez soumettre une vraie preuve';

  @override
  String get paymentFakeInstruction =>
      'Veuillez soumettre une vraie capture de virement avant l\'expiration du délai.';

  @override
  String get paymentAmountInstruction =>
      'Veuillez régler le montant complet et renvoyer la preuve avant le délai.';

  @override
  String get paymentDeadlineExpiredMsg =>
      'Délai expiré — la demande sera annulée automatiquement';

  @override
  String get paymentDeadlineContactSupport =>
      'La demande sera annulée — contactez le support si besoin';

  @override
  String paymentRemainingTime(String time) {
    return 'Temps restant : $time';
  }

  @override
  String paymentTimeLabel(String time) {
    return 'Temps restant : $time';
  }

  @override
  String get paymentDeadlineLabel => 'Délai de paiement';

  @override
  String get paymentConfirmedInfo =>
      'Paiement confirmé. Votre session sera bientôt programmée.';

  @override
  String get actionCancelFinal => 'Annuler définitivement la session';

  @override
  String get dialogCancelConfirmText2 =>
      'Êtes-vous sûr ? La demande sera annulée définitivement.';

  @override
  String get dialogBack2 => 'Retour';

  @override
  String get dialogRatingCommentOptional => 'Commentaire optionnel…';

  @override
  String get ratingThanksSnackbar => 'Merci pour votre évaluation !';

  @override
  String get sessionRatingThanks =>
      'Merci pour votre évaluation du professeur.';

  @override
  String get sessionTeacherRejectedInfo =>
      'Le professeur a refusé la demande. Vous pouvez chercher un autre professeur.';

  @override
  String get sessionReturnSearch => 'Retour à la recherche';

  @override
  String get sessionCancelledInfo => 'Cette session a été annulée.';

  @override
  String get sessionNewSession => 'Réserver une nouvelle session';

  @override
  String get sessionStudentAbsentInfo =>
      'Votre absence à cette session a été enregistrée.';

  @override
  String get sessionDisputeInfo =>
      'Un litige a été ouvert. L\'administration examine la situation et vous contactera.';

  @override
  String get sessionTeacherNoShowInfo =>
      'L\'absence du professeur a été constatée. Vous pouvez reprogrammer avec le même paiement.';

  @override
  String get sessionRescheduledSuccess =>
      'Reprogrammation effectuée avec succès';

  @override
  String sessionStartDate(String date) {
    return 'Session le $date';
  }

  @override
  String get respTeacherReview => 'Professeur — Révision de la demande';

  @override
  String get respStudentRetry => 'Vous — Renvoyer la preuve';

  @override
  String get respNoneWaiting => 'Personne — En attente du rendez-vous';

  @override
  String get respBothJoin => 'Professeur & Étudiant';

  @override
  String get respCompleted => 'Terminée';

  @override
  String get respAdminDispute => 'Administration — Résolution du litige';

  @override
  String get timeNow => 'À l\'instant';

  @override
  String timeMinutesAgo(int n) {
    return 'Il y a $n min';
  }

  @override
  String timeHoursAgo(int n) {
    return 'Il y a $n h';
  }

  @override
  String timeDaysAgo(int n) {
    return 'Il y a $n j';
  }

  @override
  String timeWeeksAgo(int n) {
    return 'Il y a $n sem';
  }

  @override
  String get timeToday => 'Aujourd\'hui';

  @override
  String get daySun => 'Dimanche';

  @override
  String get dayMon => 'Lundi';

  @override
  String get dayTue => 'Mardi';

  @override
  String get dayWed => 'Mercredi';

  @override
  String get dayThu => 'Jeudi';

  @override
  String get dayFri => 'Vendredi';

  @override
  String get daySat => 'Samedi';

  @override
  String get timePM => 'PM';

  @override
  String get timeAM => 'AM';

  @override
  String get greetingMorning => 'Bonjour,';

  @override
  String get greetingAfternoon => 'Bon après-midi,';

  @override
  String get greetingEvening => 'Bonsoir,';

  @override
  String get homeTeachersTab => 'Professeurs';

  @override
  String get homeCoursesTab => 'Cours';

  @override
  String get homePackagesTab => 'Forfaits';

  @override
  String get homeDetails => 'Détails';

  @override
  String get homeNoCoursesAvailable => 'Aucun cours disponible pour le moment';

  @override
  String get homeNoPackagesAvailable =>
      'Aucun forfait disponible pour le moment';

  @override
  String get homeLoadError => 'Échec du chargement';

  @override
  String homeLessonCount(int n) {
    return '$n leçons';
  }

  @override
  String homeHoursAbbrev(String n) {
    return '$n h';
  }

  @override
  String homePricePerMonth(String price) {
    return '$price MRU/mois';
  }

  @override
  String homePricePerYear(String price) {
    return '$price MRU/an';
  }

  @override
  String homeOriginalPrice(String price) {
    return '$price MRU';
  }

  @override
  String get homeOugiyaPerMonth => 'MRU/mois';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navCourses => 'Cours';

  @override
  String get navProfile => 'Profil';

  @override
  String get dashWelcome => 'Bonjour,';

  @override
  String get dashTeacherFallback => 'Professeur';

  @override
  String get dashAvailableLabel => 'Disponible';

  @override
  String get dashUnavailableLabel => 'Indisponible';

  @override
  String get dashWeekEarnings => 'Gains de la semaine';

  @override
  String dashCompletedNote(int n) {
    return '$n sessions terminées · après 15% commission';
  }

  @override
  String get dashNewRequests => 'Nouvelles demandes';

  @override
  String dashAwaitingBadge(String n) {
    return '$n en attente';
  }

  @override
  String get dashUpcomingSessions => 'Sessions à venir';

  @override
  String get dashNoUpcoming => 'Aucune session à venir';

  @override
  String get dashNewBadge => 'Nouveau';

  @override
  String get dashReviewBtn => 'Réviser et accepter';

  @override
  String get dashConfirmedBadge => 'Confirmée';

  @override
  String get dashLoadError => 'Impossible de charger les données';

  @override
  String get dashToggleError => 'Impossible de changer le statut';

  @override
  String get dashStatNew => 'Nouvelle dem.';

  @override
  String get dashStatToday => 'Sessions auj.';

  @override
  String get dashStatAttendance => 'Présence';

  @override
  String dashInMinutes(int n) {
    return 'Dans $n min';
  }

  @override
  String dashInHours(int n) {
    return 'Dans $n h';
  }

  @override
  String dashMinutesShort(int n) {
    return '$n min';
  }

  @override
  String get dashMorningLabel => 'matin';

  @override
  String get dashEveningLabel => 'soir';

  @override
  String get dashOugiya => 'MRU';

  @override
  String get reqTabNew => 'Nouvelles';

  @override
  String get reqTabInProgress => 'En cours';

  @override
  String get reqTabRejected => 'Refusées';

  @override
  String get reqEmptyNew => 'Aucune nouvelle demande';

  @override
  String get reqEmptyInProgress => 'Aucune session active';

  @override
  String get reqEmptyRejected => 'Aucune demande refusée';

  @override
  String get reqRejectedBadge => 'Refusé';

  @override
  String reqRejectedReason(String reason) {
    return 'Raison : $reason';
  }

  @override
  String get sessTabToday => 'Aujourd\'hui';

  @override
  String get sessTabUpcoming => 'À venir';

  @override
  String get sessTabCompleted => 'Terminées';

  @override
  String get sessEmptyToday => 'Aucune session aujourd\'hui';

  @override
  String get sessEmptyUpcoming => 'Aucune session à venir';

  @override
  String get sessEmptyCompleted => 'Aucune session terminée';

  @override
  String get sessActiveNowBadge => 'Session active';

  @override
  String sessEarningAmount(String amount) {
    return '+$amount MRU';
  }

  @override
  String get stateBadgeAwaitingPay => 'En attente de paiement';

  @override
  String get stateBadgeSubmitted => 'En attente de confirmation';

  @override
  String get stateBadgeConfirmedPay => 'Paiement confirmé';

  @override
  String get stateBadgeConfirmed => 'Confirmée';

  @override
  String get stateBadgeActive => 'En cours';

  @override
  String get stateBadgeTeacherNoShow => 'Absence prof.';

  @override
  String get stateBadgeStudentNoShow => 'Absence étudiant';

  @override
  String get stateBadgeDispute => 'Litige';

  @override
  String get stateBadgeCompleted => 'Terminée';

  @override
  String get stateBadgeCancelled => 'Annulée';

  @override
  String get stateBadgeRejected => 'Refusée';

  @override
  String get stateBadgeStudentAbsent => 'Absent étudiant';

  @override
  String get stateBadgeMyAbsence => 'Votre absence';

  @override
  String get earningsCommissionText =>
      'La plateforme prélève une commission de 15% sur chaque session et cours confirmés.';

  @override
  String get earningsCourseDesc => 'Abonnement à un cours';

  @override
  String earningsSessionDesc(String subject) {
    return 'Session $subject';
  }

  @override
  String earningsSessionDescWithStudent(String subject, String student) {
    return 'Session $subject · $student';
  }

  @override
  String get teacherSessionStatusTitle => 'Statut de la demande';

  @override
  String get teacherSubAwaitingPayment =>
      'En attente du paiement de l\'étudiant.';

  @override
  String get teacherSubPaymentSubmitted =>
      'L\'administration vérifie la preuve. Aucune action requise.';

  @override
  String get teacherSubPaymentConfirmed =>
      'Paiement confirmé. La session s\'ouvrira à l\'heure prévue.';

  @override
  String get teacherSubConfirmedBooking =>
      'Réservation confirmée — votre session est prête.';

  @override
  String get teacherSubActiveSession =>
      'La session est en cours — rejoignez maintenant.';

  @override
  String get teacherSubCompleted => 'Session terminée. Consultez vos revenus.';

  @override
  String get teacherSubDispute =>
      'Litige ouvert. L\'administration examine la situation.';

  @override
  String get teacherSubRejected => 'Vous avez refusé cette demande.';

  @override
  String get stepRequest => 'Demande';

  @override
  String get stepApproval => 'Acceptation';

  @override
  String get stepPayment => 'Paiement';

  @override
  String get stepConfirmed => 'Confirmé';

  @override
  String get stepCompleted => 'Terminé';

  @override
  String get sessionAmountLabel => 'Montant';

  @override
  String get teacherMarkNoShow => 'Enregistrer l\'absence de l\'étudiant';

  @override
  String get teacherStartSession => 'Démarrer la session';

  @override
  String get teacherCantAttend => 'Je ne peux pas — ouvrir un litige';

  @override
  String get teacherOpenDispute => 'Ouvrir un litige';

  @override
  String get teacherDisputeDialogContent =>
      'Le paiement est confirmé — annulation directe impossible.\nUn litige sera ouvert et examiné par l\'administration.';

  @override
  String get teacherCancelSessionContent =>
      'Êtes-vous sûr d\'annuler cette session ?';

  @override
  String get teacherProcessingMsg => 'Traitement en cours…';

  @override
  String get teacherCancellingMsg => 'Annulation en cours…';

  @override
  String get teacherDisputingMsg => 'Ouverture du litige…';

  @override
  String get teacherCancelSession => 'Annuler la session';

  @override
  String get teacherLoadRequestError => 'Impossible de charger la demande';

  @override
  String get teacherRequestNotFound => 'Demande introuvable';

  @override
  String get commonReject => 'Refuser';

  @override
  String get profileUserFallback => 'Utilisateur';

  @override
  String get profileTotalSessions => 'Total séances';

  @override
  String get profileCompletedStat => 'Terminées';

  @override
  String get profileTotalPayment => 'Total payé';

  @override
  String get profileSectionAccount => 'Compte et profil';

  @override
  String get profileSectionSessions => 'Sessions et paiements';

  @override
  String get profileSectionSupport => 'Assistance';

  @override
  String get profileNotifSettings => 'Notifications';

  @override
  String get profileSessionHistory => 'Historique des sessions';

  @override
  String get profileLogoutBtn => 'Déconnecter';

  @override
  String get profileDeleteAccountBtn => 'Supprimer définitivement';

  @override
  String get profileDeleteTitle => 'Supprimer le compte';

  @override
  String get profileDeleteContent =>
      'Cette action est irréversible.\nToutes vos données seront supprimées définitivement.';

  @override
  String get profileDeleteFinalTitle => 'Confirmation de suppression';

  @override
  String profileDeleteTypeHint(String phrase) {
    return 'Écrivez \"$phrase\" pour confirmer :';
  }

  @override
  String get profileDeletePhrase => 'Supprimer mon compte';

  @override
  String get profileAvatarUploadError => 'Échec du chargement de la photo';

  @override
  String get profileDeleteAccountError => 'Échec de la suppression du compte';

  @override
  String coursesActiveCount(int n) {
    return '$n actif(s)';
  }

  @override
  String coursesLessonProgress(int completed, int total) {
    return '$completed/$total leçon(s)';
  }

  @override
  String get coursesPendingInfo =>
      'Preuve de paiement en cours de vérification — sous 24h';

  @override
  String get coursesRejectedLabel => 'Abonnement refusé';

  @override
  String get coursesResub => 'Se réabonner';

  @override
  String coursesExpiresOn(String date) {
    return 'Expire le $date';
  }

  @override
  String get rescheduleTitle => 'Reprogrammer';

  @override
  String get rescheduleNoShowBanner =>
      'Le professeur était absent — une nouvelle session confirmée sera créée directement sans paiement supplémentaire.';

  @override
  String rescheduleSamePriceBanner(String amount) {
    return 'Une nouvelle session sera créée avec le même montant ($amount MRU) et nécessite l\'approbation du professeur.';
  }

  @override
  String get reschedulePickDay => 'Choisissez un jour';

  @override
  String get reschedulePickTime => 'Choisissez une heure';

  @override
  String get rescheduleErrSelectTime => 'Sélectionnez le jour et l\'heure';

  @override
  String get rescheduleErrDoubleBooked =>
      'Ce créneau est déjà réservé, choisissez un autre';

  @override
  String get rescheduleSubmitBtn => 'Envoyer la demande de reprogrammation';

  @override
  String get helpContactTab => 'Nous contacter';

  @override
  String get helpTermsTab => 'Conditions d\'utilisation';

  @override
  String get helpHeroTitle => 'Nous sommes là pour vous aider';

  @override
  String get helpHeroSub =>
      'Contactez-nous à tout moment, nous vous répondrons dès que possible';

  @override
  String get helpCallUs => 'Appelez-nous';

  @override
  String get helpEmailUs => 'Envoyez-nous un e-mail';

  @override
  String helpCopied(String label) {
    return '$label copié';
  }

  @override
  String get helpFaqTitle => 'Questions fréquentes';

  @override
  String get faqQ1 => 'Comment réserver une session avec un professeur ?';

  @override
  String get faqA1 =>
      'Recherchez le professeur souhaité sur la page d\'accueil, appuyez sur son nom pour voir son profil, puis appuyez sur \"Réserver une session\" et choisissez la date et l\'heure.';

  @override
  String get faqQ2 => 'Quels sont les moyens de paiement disponibles ?';

  @override
  String get faqA2 =>
      'Vous pouvez payer par virement bancaire. Après l\'envoi de la demande, un numéro de compte vous est communiqué et il vous est demandé de télécharger le reçu de paiement.';

  @override
  String get faqQ3 => 'Que se passe-t-il si le professeur est absent ?';

  @override
  String get faqA3 =>
      'En cas d\'absence du professeur, la session est reprogrammée ou le montant est intégralement remboursé. Veuillez nous contacter immédiatement.';

  @override
  String get faqQ4 => 'Comment évaluer le professeur ?';

  @override
  String get faqA4 =>
      'À la fin de la session, une fenêtre apparaîtra pour évaluer votre expérience avec le professeur de 1 à 5 étoiles avec la possibilité d\'écrire un commentaire.';

  @override
  String get privacyPolicyContent =>
      '# Politique de confidentialité\n\nDernière mise à jour : janvier 2025\n\n## Introduction\n\nChez Sawelni, nous nous engageons à protéger votre vie privée. Cette politique explique comment nous collectons, utilisons et protégeons vos informations lorsque vous utilisez notre application.\n\n## Informations que nous collectons\n\nNous collectons les informations que vous fournissez directement lors de la création d\'un compte, telles que : nom, adresse e-mail, numéro de téléphone et photo de profil. Nous collectons également des données d\'utilisation de l\'application telles que les sessions réservées et les paiements.\n\n## Comment nous utilisons vos informations\n\nNous utilisons vos données pour exploiter et améliorer le service, faciliter la communication entre étudiants et professeurs, traiter les paiements et envoyer des notifications liées aux sessions.\n\n## Partage des informations\n\nNous ne vendons pas vos données à des tiers. Nous pouvons partager vos informations avec des prestataires de services nécessaires au fonctionnement de la plateforme (comme les services de paiement) uniquement dans le cadre d\'accords de confidentialité stricts.\n\n## Protection des données\n\nNous utilisons un chiffrement de premier ordre pour protéger vos données. Tout est stocké en toute sécurité sur des serveurs certifiés.\n\n## Vos droits\n\nVous pouvez à tout moment : consulter vos données, les corriger ou en demander la suppression. Contactez-nous via : ahmedelkentawi@gmail.com\n\n## Nous contacter\n\nPour toute question concernant cette politique, veuillez nous contacter au : 42740370 ou par e-mail : ahmedelkentawi@gmail.com';

  @override
  String get termsContent =>
      '# Conditions d\'utilisation\n\nDernière mise à jour : janvier 2025\n\n## Acceptation des conditions\n\nEn utilisant l\'application Sawelni, vous acceptez ces conditions dans leur intégralité. Si vous n\'acceptez pas, veuillez cesser d\'utiliser l\'application.\n\n## Le service\n\nSawelni est une plateforme qui met en relation des étudiants et des professeurs pour des sessions d\'enseignement privées. Nous sommes un intermédiaire et ne sommes pas partie au contrat entre l\'étudiant et le professeur.\n\n## Compte utilisateur\n\nVous êtes responsable de la confidentialité de vos identifiants. Les informations fournies doivent être exactes et à jour. Nous nous réservons le droit de suspendre les comptes qui enfreignent les conditions.\n\n## Sessions et paiements\n\nLes sessions se déroulent selon les horaires convenus. Le paiement doit être effectué avant la confirmation de la session. En cas d\'annulation plus de 24 heures à l\'avance, un remboursement est possible selon la politique de remboursement.\n\n## Comportement des utilisateurs\n\nIl est interdit d\'utiliser l\'application à des fins illégales ou abusives. Il est interdit de partager le contenu des sessions sans autorisation. Il est interdit d\'usurper l\'identité d\'autrui.\n\n## Limitation de responsabilité\n\nNous nous efforçons de fournir le meilleur service possible, mais nous ne garantissons pas l\'absence d\'interruptions. La qualité de l\'enseignement dépend du professeur et Sawelni n\'est pas responsable des résultats académiques.\n\n## Modifications\n\nNous nous réservons le droit de modifier ces conditions à tout moment. Les utilisateurs seront informés des changements importants via les notifications dans l\'application.\n\n## Nous contacter\n\nPour toute question : téléphone 42740370 ou e-mail : ahmedelkentawi@gmail.com';

  @override
  String courseSubscribersCount(String n) {
    return '$n abonné(s)';
  }

  @override
  String courseRatingCount(int n) {
    return '($n avis)';
  }

  @override
  String get courseLessonsTitle => 'Leçons';

  @override
  String get courseNoLessons => 'Aucune leçon disponible pour le moment';

  @override
  String courseLockedCount(int n) {
    return '$n leçon(s) réservée(s) aux abonnés';
  }

  @override
  String get courseLockedBody =>
      'Abonnez-vous maintenant pour accéder à tout le contenu';

  @override
  String get courseSubscribeNow => 'S\'abonner maintenant';

  @override
  String get courseFreeLabel => 'Gratuit';

  @override
  String coursePriceYearly(String n) {
    return '$n MRU/an';
  }

  @override
  String get courseSubscribedLabel => 'Abonné';

  @override
  String get coursePendingLabel => 'En vérification';

  @override
  String get courseSubPendingTitle =>
      'Votre abonnement est en cours de vérification';

  @override
  String get courseSubPendingBody =>
      'Votre abonnement sera activé sous 24h après confirmation du paiement.';

  @override
  String get courseLessonLockedTitle => 'Cette leçon est réservée aux abonnés';

  @override
  String courseLessonLockedBody(String title) {
    return 'Abonnez-vous à \"$title\" pour accéder à toutes les leçons';
  }

  @override
  String get lessonQuizFallback => 'Exercice';

  @override
  String get lessonDone => 'Terminé ✓';

  @override
  String get lessonQuizDoneLabel => 'Exercice terminé';

  @override
  String lessonAnswerAll(int answered, int total) {
    return 'Répondez à toutes les questions ($answered/$total)';
  }

  @override
  String get lessonSubmitAnswers => 'Soumettre les réponses';

  @override
  String get lessonQuizPassed => 'Bravo ! Vous avez réussi !';

  @override
  String get lessonQuizFailed => 'Vous pouvez réessayer';

  @override
  String lessonQuizScore(int correct, int total, int pct) {
    return 'Résultat : $correct/$total correct ($pct%)';
  }

  @override
  String get lessonNoVideo => 'Aucune vidéo disponible pour cette leçon';

  @override
  String get lessonVideoHint =>
      'Regardez toute la leçon puis appuyez sur \"Terminé\" pour enregistrer votre progression';

  @override
  String get lessonFreePreview => 'Ceci est une leçon d\'aperçu gratuite';

  @override
  String get lessonVideoDoneLabel => 'Leçon terminée';

  @override
  String get lessonSubscribeToAccess =>
      'Abonnez-vous pour accéder à toutes les leçons';

  @override
  String get lessonBackToList => 'Retour à la liste';

  @override
  String get lessonRatingTitle => 'Comment était la leçon ?';

  @override
  String get lessonRatingSubtitle =>
      'Évaluez ce cours pour aider les autres étudiants';

  @override
  String get lessonRatingLater => 'Plus tard';

  @override
  String get lessonRatingSubmit => 'Envoyer l\'évaluation';

  @override
  String get requestSentTitle => 'Statut de la demande';

  @override
  String get requestSentBadge => 'En attente d\'approbation';

  @override
  String get requestSentHeadline => 'Demande envoyée';

  @override
  String get requestSentBody =>
      'Le professeur examinera votre demande et répondra généralement dans les 2 heures. Nous vous notifierons dès l\'approbation pour procéder au paiement.';

  @override
  String get requestSentCancelBtn => 'Annuler la demande';

  @override
  String get requestSentTrackBtn => 'Suivre l\'état';

  @override
  String get requestSentCancelConfirm =>
      'Êtes-vous sûr de vouloir annuler cette demande ?';

  @override
  String get requestSentCancelYes => 'Oui, annuler';

  @override
  String get paymentSubmittedTitle => 'Statut du paiement';

  @override
  String get paymentSubmittedBadge => 'En cours de vérification';

  @override
  String get paymentSubmittedHeadline =>
      'L\'administration vérifie votre paiement';

  @override
  String get paymentSubmittedBody =>
      'Nous avons reçu la preuve de virement. Notre équipe la vérifie habituellement en 30 minutes. La réservation passera automatiquement à « Confirmée ».';

  @override
  String get paymentMethodLabel => 'Méthode';

  @override
  String get paymentReferenceLabel => 'Référence';

  @override
  String get paymentSubmittedResponsibleAdmin =>
      'Administration — Confirmation du paiement';

  @override
  String get paymentSubmittedViewDetails => 'Voir les détails de la session';

  @override
  String get filterTitle => 'Filtrer les résultats';

  @override
  String get filterReset => 'Réinitialiser';

  @override
  String get filterSubject => 'Matière';

  @override
  String get filterLevel => 'Niveau scolaire';

  @override
  String get filterPriceRange => 'Fourchette de prix (MRU/h)';

  @override
  String get filterOnlineOnly => 'Disponibles maintenant uniquement';

  @override
  String get filterShowResults => 'Afficher les résultats';

  @override
  String get subscriptionTitle => 'Abonnement';

  @override
  String get subscriptionErrNoProof =>
      'Veuillez d\'abord télécharger la preuve de paiement';

  @override
  String subscriptionErrGeneral(String error) {
    return 'Une erreur s\'est produite : $error';
  }

  @override
  String get subscriptionChoosePlan => 'Choisir le plan';

  @override
  String get subscriptionPlanMonthly => 'Mensuel';

  @override
  String get subscriptionPerMonthLabel => 'Chaque mois';

  @override
  String get subscriptionPlanYearly => 'Annuel';

  @override
  String subscriptionSavePct(int pct) {
    return 'Économisez $pct%';
  }

  @override
  String get subscriptionTypePackage => 'Forfait';

  @override
  String get subscriptionTypeCourse => 'Cours';

  @override
  String get subscriptionNoMethods => 'Aucun mode de paiement disponible';

  @override
  String get subscriptionPaymentMethodLabel => 'Mode de paiement';

  @override
  String subscriptionAccountNumber(String number) {
    return 'Numéro de compte : $number';
  }

  @override
  String subscriptionHolder(String holder) {
    return 'Bénéficiaire : $holder';
  }

  @override
  String get subscriptionProofTitle => 'Preuve de paiement';

  @override
  String get subscriptionProofHint =>
      'Appuyez pour télécharger la preuve de paiement';

  @override
  String get subscriptionPerYear => 'MRU/an';

  @override
  String get subscriptionPerMonth => 'MRU/mois';

  @override
  String get subscriptionConfirm => 'Confirmer l\'abonnement';

  @override
  String get subscriptionSubmitting => 'Envoi en cours...';

  @override
  String get subscriptionReviewNote =>
      'La preuve de paiement sera examinée par l\'administration dans les 24 heures';

  @override
  String get subPendingActivatedTitle => 'Votre abonnement est activé !';

  @override
  String get subPendingActivatedBody =>
      'Vous pouvez maintenant accéder à tout le contenu du cours.';

  @override
  String get subPendingRedirecting => 'Redirection vers vos cours...';

  @override
  String get subPendingTitle => 'Votre abonnement est en cours d\'examen';

  @override
  String get subPendingRejectedBody =>
      'La preuve de paiement n\'a pas pu être acceptée. Veuillez contacter l\'administration ou réessayer avec une preuve correcte.';

  @override
  String get subPendingPendingBody =>
      'Nous avons reçu votre preuve de paiement. Votre abonnement sera activé dans les 24 heures après vérification.';

  @override
  String get subPendingStep1 => 'Preuve de paiement téléchargée avec succès';

  @override
  String get subPendingStep2 => 'Examen de l\'administration (jusqu\'à 24h)';

  @override
  String get subPendingStep3 =>
      'Activation de l\'abonnement et accès au contenu';

  @override
  String get subPendingBackCourses => 'Retour à mes cours';

  @override
  String get subPendingViewCourses => 'Voir mes cours';

  @override
  String get subPendingBackHome => 'Retour à l\'accueil';

  @override
  String get payHistTotalPaid => 'Total payé';

  @override
  String get payHistTotalTransactions => 'Total des transactions';

  @override
  String get payHistStatPending => 'En cours';

  @override
  String get payHistStatRejected => 'Refusé';

  @override
  String get payHistFilterAll => 'Tout';

  @override
  String get payHistFilterSessions => 'Sessions';

  @override
  String get payHistFilterSubscriptions => 'Abonnements';

  @override
  String get payHistTypeSession => 'Session';

  @override
  String get payHistTypeSubscription => 'Abonnement';

  @override
  String get payHistViewSession => 'Voir les détails de la session';

  @override
  String get payHistViewCourse => 'Voir le cours';

  @override
  String get payHistEmpty => 'Aucun paiement pour l\'instant';

  @override
  String get payHistEmptyAll =>
      'Tous vos paiements de sessions et d\'abonnements apparaîtront ici';

  @override
  String get payHistEmptySessions => 'Aucun paiement de session';

  @override
  String get payHistEmptySubscriptions => 'Aucun paiement d\'abonnement';

  @override
  String get payHistLoadError =>
      'Impossible de charger l\'historique des paiements';

  @override
  String get payHistStatusPending => 'En cours';

  @override
  String get payHistStatusConfirmed => 'Accepté';

  @override
  String get payHistStatusRejected => 'Refusé';

  @override
  String get payHistStatusWaiting => 'En attente';

  @override
  String get payHistStatusActive => 'Actif';

  @override
  String get payHistStatusExpired => 'Expiré';

  @override
  String get timeYesterday => 'Hier';

  @override
  String get packageTypeLabel => 'Forfait';

  @override
  String get packageCoursesStatLabel => 'Cours';

  @override
  String get packageLessonsStatLabel => 'Leçon(s)';

  @override
  String get packageNoCourses => 'Aucun cours dans ce forfait pour l\'instant';

  @override
  String get packageCoursesTitle => 'Cours inclus';

  @override
  String get packageSubscribeBtn => 'S\'abonner au forfait';

  @override
  String editProfileUploadError(String error) {
    return 'Échec du téléchargement : $error';
  }

  @override
  String get editProfileNameEmpty => 'Le nom ne peut pas être vide';

  @override
  String get editProfileSaved => 'Profil mis à jour avec succès';

  @override
  String get editProfileChangePhoto => 'Appuyez pour changer la photo';

  @override
  String get editProfileSaveBtn => 'Enregistrer les modifications';

  @override
  String get changePassErrTooShort =>
      'Le mot de passe doit comporter au moins 8 caractères';

  @override
  String get changePassErrMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get changePassSuccess => 'Mot de passe modifié avec succès';

  @override
  String get changePassErrFailed =>
      'Échec de la modification — vérifiez votre connexion ou reconnectez-vous';

  @override
  String get changePassInfoBanner =>
      'Vous devrez vous reconnecter après avoir modifié votre mot de passe';

  @override
  String get changePassNewLabel => 'Nouveau mot de passe';

  @override
  String get changePassNewHint => '8 caractères minimum';

  @override
  String get changePassConfirmLabel => 'Confirmer le mot de passe';

  @override
  String get changePassConfirmHint => 'Répétez le mot de passe';

  @override
  String get myRatingsLoadError => 'Impossible de charger les évaluations';

  @override
  String get myRatingsEmpty => 'Aucune évaluation pour l\'instant';

  @override
  String get myRatingsEmptyHint =>
      'Après avoir terminé un cours, vous serez invité à l\'évaluer';

  @override
  String get reqSessionTitle => 'Demander une session';

  @override
  String get reqSessionChooseLevel => 'Choisissez votre niveau';

  @override
  String get reqSessionErrNoSlot => 'Veuillez choisir un créneau disponible';

  @override
  String get reqSessionErrBooked =>
      'Ce créneau est déjà réservé, choisissez un autre';

  @override
  String get reqSessionErrNoLevel => 'Veuillez indiquer votre niveau scolaire';

  @override
  String get reqSessionErrGeneral =>
      'Une erreur s\'est produite lors de l\'envoi, réessayez';

  @override
  String get reqSessionErrLoadTeacher =>
      'Impossible de charger les données du professeur';

  @override
  String get reqSessionTeacherNotFound => 'Professeur introuvable';

  @override
  String get reqSessionToday => 'Aujourd\'hui';

  @override
  String get reqSessionUnavailableHint => 'Les jours grisés sont indisponibles';

  @override
  String get reqSessionNoSlotsLeft => 'Aucun créneau disponible pour ce jour';

  @override
  String get reqSessionTeacherUnavailable =>
      'Le professeur n\'est pas disponible ce jour';

  @override
  String get reqSessionSelectDay => 'Choisissez le jour';

  @override
  String get reqSessionDuration => 'Durée';

  @override
  String get reqSessionSelectTime => 'Choisissez l\'heure';

  @override
  String get reqSessionYourLevel => 'Votre niveau scolaire *';

  @override
  String get reqSessionChooseLevelHint => 'Choisissez votre niveau…';

  @override
  String get reqSessionNoteLabel => 'Description (facultatif)';

  @override
  String get reqSessionNoteHint => 'Décrivez ce dont vous avez besoin…';

  @override
  String get reqSessionTotal => 'Total estimé';

  @override
  String get reqSessionPaymentNote =>
      'Le paiement commence après approbation du professeur. Aucun paiement requis maintenant.';

  @override
  String get reqSessionSubmit => 'Envoyer la demande';

  @override
  String get unitMinAbbrev => 'min';

  @override
  String get unitMinFull => 'minute';

  @override
  String get unitOugiyaPerHour => 'MRU/h';

  @override
  String get timeAmAbbrev => 'am';

  @override
  String get timePmAbbrev => 'pm';

  @override
  String get liveSessionErrStart => 'Erreur lors du démarrage de la session';

  @override
  String get liveSessionErrEnd => 'Erreur lors de la fin de la session';

  @override
  String get liveSessionStudentFallback => 'Étudiant';

  @override
  String get liveSessionStartBtn => 'Démarrer la session';

  @override
  String get liveSessionLive => 'EN DIRECT';

  @override
  String get liveSessionEndBtn => 'Terminer';

  @override
  String get liveSessionEndTitle => 'Terminer la session ?';

  @override
  String get liveSessionEndBody =>
      'Êtes-vous sûr de vouloir terminer la session ? L\'étudiant sera notifié.';

  @override
  String get liveSessionEndContinue => 'Continuer';

  @override
  String get liveSessionEndConfirm => 'Terminer';

  @override
  String get noShowTitle => 'Absence de l\'étudiant';

  @override
  String get noShowHeadline => 'L\'étudiant n\'a pas rejoint';

  @override
  String noShowBodyText(String name) {
    return '$name n\'est pas présent(e). Vous pouvez terminer la session et enregistrer l\'absence — votre salaire est préservé conformément à la politique d\'assiduité.';
  }

  @override
  String get noShowWaitTime => 'Temps d\'attente';

  @override
  String get noShowYourEarnings => 'Votre salaire garanti';

  @override
  String get noShowWaitMore => 'Attendre encore';

  @override
  String get noShowRecordAndEnd => 'Enregistrer l\'absence et terminer';

  @override
  String get noShowSuccessMsg =>
      'Absence enregistrée — votre salaire est sécurisé';

  @override
  String get noShowStudentDefault => 'L\'étudiant';

  @override
  String noShowErrGeneral(String error) {
    return 'Erreur : $error';
  }

  @override
  String teacherRatingCount(int count) {
    return '$count avis';
  }

  @override
  String get teacherRatingsEmptyHint =>
      'Les avis des étudiants apparaîtront ici après les sessions';

  @override
  String get disputePrefix => 'Litige #';

  @override
  String get disputeStatusOpen => 'LITIGE · Votre réponse est requise';

  @override
  String get disputeStatusResolved => 'Résolu';

  @override
  String get disputeOpenedBody =>
      'L\'étudiant a ouvert un litige pour une session';

  @override
  String get disputeResolvedBody => 'Le litige est résolu';

  @override
  String get disputeDeadlineNote =>
      'Soumettez votre réponse et preuves sous 48 heures, sinon le litige sera tranché en faveur de l\'étudiant. Le montant est gelé jusqu\'à la décision.';

  @override
  String get disputeReasonLabel => 'Motif du litige';

  @override
  String get disputeSubjectLabel => 'Matière';

  @override
  String get disputeStudentLabel => 'Étudiant';

  @override
  String get disputeFrozenAmtLabel => 'Montant gelé';

  @override
  String get disputeComplaintTitle => 'Plainte de l\'étudiant';

  @override
  String get disputeSentResponseTitle => 'Votre réponse envoyée';

  @override
  String get disputeResponseHint =>
      'Écrivez votre réponse et expliquez ce qui s\'est passé de votre côté…';

  @override
  String disputeEvidenceCount(int count) {
    return 'Preuves jointes ($count)';
  }

  @override
  String get disputeImageLabel => 'Image';

  @override
  String get disputeAdminDecisionLabel => 'La décision finale revient à';

  @override
  String get disputeAdminDecisionValue =>
      'L\'administration — après avoir entendu les deux parties';

  @override
  String get disputeAttachBtn => 'Joindre une preuve';

  @override
  String get disputeSubmitBtn => 'Envoyer la réponse';

  @override
  String disputeUploadErr(String error) {
    return 'Impossible de télécharger l\'image : $error';
  }

  @override
  String get disputeErrEmptyResponse =>
      'Veuillez d\'abord écrire votre réponse';

  @override
  String get disputeResponseSent =>
      'Votre réponse a été envoyée — l\'administration va l\'examiner';

  @override
  String disputeLoadErr(String error) {
    return 'Impossible de charger : $error';
  }

  @override
  String disputeSubmitErr(String error) {
    return 'Erreur : $error';
  }

  @override
  String get availTitle => 'Gérer les disponibilités';

  @override
  String get availStartTime => 'Heure de début';

  @override
  String get availEndTime => 'Heure de fin';

  @override
  String get availErrEndBeforeStart =>
      'L\'heure de fin doit être après l\'heure de début';

  @override
  String availErrGeneral(String error) {
    return 'Erreur : $error';
  }

  @override
  String get availInfoText =>
      'Définissez les jours et heures où vous êtes disponible. Les étudiants pourront réserver des sessions pendant ces créneaux.';

  @override
  String get availAddSlotBtn => 'Ajouter un créneau';

  @override
  String get availNoSlots => 'Aucun créneau défini';

  @override
  String get weekdaySun => 'Dimanche';

  @override
  String get weekdayMon => 'Lundi';

  @override
  String get weekdayTue => 'Mardi';

  @override
  String get weekdayWed => 'Mercredi';

  @override
  String get weekdayThu => 'Jeudi';

  @override
  String get weekdayFri => 'Vendredi';

  @override
  String get weekdaySat => 'Samedi';

  @override
  String get weekdayShortSun => 'Dim';

  @override
  String get weekdayShortMon => 'Lun';

  @override
  String get weekdayShortTue => 'Mar';

  @override
  String get weekdayShortWed => 'Mer';

  @override
  String get weekdayShortThu => 'Jeu';

  @override
  String get weekdayShortFri => 'Ven';

  @override
  String get weekdayShortSat => 'Sam';

  @override
  String get dialogCancel => 'Annuler';

  @override
  String get dialogConfirm => 'Confirmer';

  @override
  String get onboardingWelcomeTitle => 'Bienvenue en tant que professeur';

  @override
  String get onboardingWelcomeBody =>
      'Complétez votre profil pour commencer à recevoir des étudiants. L\'équipe examinera votre demande dans les 24 heures.';

  @override
  String get onboardingErrNoSubject => 'Choisissez au moins une matière';

  @override
  String onboardingErrMaxSubjects(int max) {
    return 'Vous ne pouvez pas choisir plus de $max matières';
  }

  @override
  String get onboardingErrSave => 'Une erreur s\'est produite, réessayez';

  @override
  String get onboardingBioLabel => 'À propos de vous';

  @override
  String get onboardingBioHint =>
      'Décrivez votre expérience et votre méthode d\'enseignement…';

  @override
  String get onboardingBioTooShort => 'Écrivez au moins 20 caractères';

  @override
  String get onboardingPriceLabel => 'Prix par heure (MRU)';

  @override
  String get onboardingPriceHint => 'Exemple : 500';

  @override
  String get onboardingPriceRequired => 'Entrez le prix';

  @override
  String get onboardingPriceInvalid => 'Entrez un prix valide';

  @override
  String get onboardingYearsExp => 'Années d\'expérience';

  @override
  String get onboardingSubjectsLabel => 'Matières enseignées';

  @override
  String onboardingSubjectsHint(int count, int max) {
    return 'Choisissez une ou deux matières max ($count/$max)';
  }

  @override
  String get onboardingInfoNote =>
      'Après l\'envoi, l\'équipe vérifiera vos données et activera votre compte dans les 24 heures.';

  @override
  String get onboardingSubmitBtn => 'Envoyer la demande pour examen';

  @override
  String get onboardingSkipBtn => 'Ignorer — Je compléterai plus tard';

  @override
  String get profileDeleteAccount => 'Supprimer le compte';

  @override
  String get profileDeleteAccountBody =>
      'Cette action est irréversible.\nToutes vos données seront définitivement supprimées.';

  @override
  String get profileDeleteBtn => 'Supprimer';

  @override
  String get profileDeleteConfirmTitle =>
      'Confirmation de suppression définitive';

  @override
  String profileDeleteConfirmBody(String phrase) {
    return 'Écrivez \"$phrase\" pour confirmer :';
  }

  @override
  String get profileDeleteConfirmPhrase => 'supprimer mon compte';

  @override
  String profileDeleteAccountErr(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get profileDeleteAccountLink => 'Supprimer définitivement le compte';

  @override
  String get profileLogoutConfirmBody =>
      'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get profileLogoutConfirmYes => 'Quitter';

  @override
  String get teacherDefaultName => 'Professeur';

  @override
  String get teacherStatusApprovedActive => 'Professeur vérifié · Actif';

  @override
  String get teacherStatusApprovedInactive => 'Professeur vérifié · Inactif';

  @override
  String get teacherStatusPending => 'En attente d\'approbation';

  @override
  String get teacherStatSessions => 'session(s) complétée(s)';

  @override
  String teacherStatRating(int count) {
    return 'Avis ($count)';
  }

  @override
  String get teacherStatAttendance => 'Assiduité';

  @override
  String get profileSectionEarnings => 'Revenus et paiements';

  @override
  String get teacherOnboardingMenuItem => 'Vérification du compte';

  @override
  String get teacherMenuEarnings => 'Historique des revenus';

  @override
  String get profileMenuHelp => 'Centre d\'aide';

  @override
  String get profileMenuPrivacy => 'Politique de confidentialité';

  @override
  String get profileMenuTerms => 'Conditions d\'utilisation';

  @override
  String get teacherCompleteProfile =>
      'Complétez la vérification de votre compte';

  @override
  String get teacherCompleteProfileHint =>
      'Ajoutez vos informations pour recevoir des étudiants';

  @override
  String get teacherBadgeRequired => 'Requis';

  @override
  String get profileAppVersion => 'Sawelni · Version 1.0.0';

  @override
  String get teacherVerifiedBadge => 'Vérifié';

  @override
  String teacherYearsExpBadge(int years) {
    return '$years an(s) d\'expérience';
  }

  @override
  String get teacherBioLabel => 'Biographie';

  @override
  String get teacherSubjectsTitle => 'Matières';

  @override
  String get teacherAvailToday => 'Disponibilités · Aujourd\'hui';

  @override
  String get teacherAvailViewWeek => 'Voir la semaine';

  @override
  String get teacherNoSlotsToday => 'Aucun créneau disponible aujourd\'hui';

  @override
  String teacherPublicReviews(int count) {
    return 'Avis des étudiants ($count)';
  }
}
