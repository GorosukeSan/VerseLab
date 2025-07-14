using { /Fortnite.com/Characters }
using { /Fortnite.com/Game }
using { /Fortnite.com/Playspaces }
using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }
using { /Verse.org/SpatialMath }
using { /Verse.org/Assets }
using { /UnrealEngine.com/Temporary }
using { /Fortnite.com/Devices }

trace_interaction_state<public> := enum<open>:
    Free
    Ready
    Interact

trace_interaction_transform<public> := class:
    ViewRotation<public>:rotation
    ViewLocation<public>:transform

trace_interaction_result<public> := class(scene_event):
    Transform<public>:trace_interaction_transform
    TargetEntity<public>:entity
    Instigator<public>:player
    InteractState<public>:trace_interaction_state

widget_update_event<public> := class(scene_event):
    Player<public>:player
    State<public>:trace_interaction_state


MakeTraceInteractionTransform<public><constructor>(InFortCharacter:fort_character)<transacts> := trace_interaction_transform:
    ViewRotation := SpatialMath.FromRotation(InFortCharacter.GetViewRotation())
    ViewLocation := transform:
        Translation := SpatialMath.FromVector3(InFortCharacter.GetViewLocation())

trace_interaction_manager_component<public> := class<final_super>(component):

    @editable
    InteractionRange<public>:float = 512.0

    @editable
    HoldInput<public>:input_trigger_device

    var<private> InteractingPlayers<public>:[player]trace_interaction_result = map{}
    var PrePhysicsCancelable<private>:?cancelable = false

    OnBeginSimulation<override>():void=
        if:
            FortRoundManager := Entity.GetFortRoundManager[]
        then:
            FortRoundManager.SubscribeRoundStarted(OnRoundStarted)
            FortRoundManager.SubscribeRoundEnded(OnRoundEnded)

    OnRoundStarted<private>():void=
        set PrePhysicsCancelable = option:
            TickEvents.PrePhysics.Subscribe(OnUpdate)

    OnRoundEnded<private>():void=
        if(Cancelable := PrePhysicsCancelable?):
            Cancelable.Cancel()
            set PrePhysicsCancelable = false

    OnUpdate<private>(DeltaTime:float):void=
        if:
            FortPlayspace := Entity.GetPlayspaceForEntity[]
        then:
            defer:
                for:
                    PlayerElement -> CurrentTraceInteractionResult : InteractingPlayers
                do:
                    if:
                        CheckTraceInteractionResult := GetInteractionEntity[PlayerElement]
                        CurrentTraceInteractionResult.TargetEntity = CheckTraceInteractionResult.TargetEntity
                    then:
                        if(not HoldInput.IsHeld[PlayerElement]):
                            NewTraceInteractionResult := trace_interaction_result:
                                Transform := CurrentTraceInteractionResult.Transform
                                TargetEntity := CurrentTraceInteractionResult.TargetEntity
                                Instigator := PlayerElement
                                InteractState := trace_interaction_state.Ready
                            CurrentTraceInteractionResult.TargetEntity.SendDirect(NewTraceInteractionResult)
                    else:
                        NewTraceInteractionResult := trace_interaction_result:
                            Transform := CurrentTraceInteractionResult.Transform
                            TargetEntity := CurrentTraceInteractionResult.TargetEntity
                            Instigator := PlayerElement
                            InteractState := trace_interaction_state.Free
                        CurrentTraceInteractionResult.TargetEntity.SendDirect(NewTraceInteractionResult)
                        set InteractingPlayers = InteractingPlayers.RemoveKey(PlayerElement)

            for:
                PlayerElement : FortPlayspace.GetPlayers()
                TraceInteractionResult := GetInteractionEntity[PlayerElement]
            do:
                if(HoldInput.IsHeld[PlayerElement]):
                    TraceInteractionResult.TargetEntity.SendDirect(TraceInteractionResult)
                if:
                    set InteractingPlayers[PlayerElement] = TraceInteractionResult

            for:
                PlayerElement : FortPlayspace.GetPlayers()
            do:
                WidgetupdateEvent := widget_update_event:
                    Player := PlayerElement
                    State := 
                        if:
                            Result := InteractingPlayers[PlayerElement]
                        then:
                            if:
                                Result.InteractState = trace_interaction_state.Interact
                            then:
                                trace_interaction_state.Interact
                            else:
                                trace_interaction_state.Ready
                        else:
                            trace_interaction_state.Free
                Entity.SendDirect(WidgetupdateEvent)

    GetInteractionEntity<private>(InPlayer:player)<transacts><decides>:trace_interaction_result=
        FortCharacter := InPlayer.GetFortCharacter[]
        TraceInteractionTransform := MakeTraceInteractionTransform(FortCharacter)
        ForwardVector := TraceInteractionTransform.ViewRotation.GetForwardAxis() * InteractionRange
        SweepHitResult := 
            (
                for:
                    SweepHitElement : Entity.FindSweepHits(ForwardVector, TraceInteractionTransform.ViewLocation, collision_point{})
                do:
                    SweepHitElement
            )[0]
        trace_interaction_result:
            Transform := TraceInteractionTransform
            TargetEntity := SweepHitResult.TargetComponent.Entity
            Instigator := InPlayer
            InteractState := 
                if(HoldInput.IsHeld[InPlayer]):
                    trace_interaction_state.Interact
                else:
                    trace_interaction_state.Ready

trace_interaction_widget_component<public> := class<final_super><final>(component):

    @editable
    DefaultImage<public>:texture

    @editable
    ReadyImage<public>:texture

    @editable
    InteractImage<public>:texture

    var<private> WidgetPerPlayer<public>:[player]trace_interaction_widget = map{}

    UpdateCrossHair<public>(InPlayer:player, InState:trace_interaction_state):void=
        if(Widget := WidgetPerPlayer[InPlayer]):
            case(InState):
                trace_interaction_state.Free=>
                    Widget.UpdateCrossHair(DefaultImage)
                trace_interaction_state.Ready=>
                    Widget.UpdateCrossHair(ReadyImage)
                trace_interaction_state.Interact=>
                    Widget.UpdateCrossHair(InteractImage)
                _=>
                    Widget.UpdateCrossHair(DefaultImage)

    OnBeginSimulation<override>():void=
        if:
            FortRoundManager := Entity.GetFortRoundManager[]
        then:
            FortRoundManager.SubscribeRoundStarted(OnRoundStarted)
            FortRoundManager.SubscribeRoundEnded(OnRoundEnded)

    OnRoundStarted<private>():void=
        if:
            FortPlayspace := Entity.GetPlayspaceForEntity[]
        then:
            for:
                PlayerElement : FortPlayspace.GetPlayers()
            do:
                OnPlay(PlayerElement)
            FortPlayspace.PlayerAddedEvent().Subscribe(OnPlay)
            FortPlayspace.PlayerRemovedEvent().Subscribe(OnLeave)

    OnRoundEnded<private>():void=
        for:
            PlayerElement -> Widget : WidgetPerPlayer
        do:
            Widget.RemoveUI()
        set WidgetPerPlayer = map{}

    OnPlay<private>(InPlayer:player):void=
        NewWidget := MakeTraceInteractionWidget(InPlayer, DefaultImage)
        NewWidget.AddGameplayUI()
        if:
            set WidgetPerPlayer[InPlayer] = NewWidget

    OnLeave<private>(InPlayer:player):void=
        if:
            Widget := WidgetPerPlayer[InPlayer]
        then:
            Widget.RemoveUI()
            set WidgetPerPlayer = WidgetPerPlayer.RemoveKey(InPlayer)

    OnReceive<override>(SceneEvent:scene_event):logic=
        if:
            WidgetUpdateEvent := widget_update_event[SceneEvent]
        then:
            UpdateCrossHair(WidgetUpdateEvent.Player, WidgetUpdateEvent.State)
            true
        else:
            false

trace_interaction_object_component<public> := class<final_super>(component):

    OnInteract<public>(Result:trace_interaction_result):void=
        Print(ToDiagnostic(Result.InteractState))

    OnReceive<override>(SceneEvent:scene_event):logic=
        if:
            TraceInteractionResult := trace_interaction_result[SceneEvent]
        then:
            OnInteract(TraceInteractionResult)
            true
        else:
            false