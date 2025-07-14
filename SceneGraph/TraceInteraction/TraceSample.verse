using { /Verse.org/Simulation }
using { /Verse.org/Assets }

using { Meshes }

trace_interaction_object_material_component<public> := class<final_super>(trace_interaction_object_component):

    @editable
    InteractingMaterial<public>:material

    var MaybeTargetMesh:?tuple(SM_Sphere, material) = false
    var LastInteractState:trace_interaction_state = trace_interaction_state.Free

    OnBeginSimulation<override>():void=
        if(TargetComponent := Entity.GetComponent[SM_Sphere]):
            set MaybeTargetMesh = option{(TargetComponent, TargetComponent.Material_0)}

    OnInteract<override>(Result:trace_interaction_result):void=
        if:
            TargetMesh := MaybeTargetMesh?
            LastInteractState <> Result.InteractState
        then:
            set LastInteractState = Result.InteractState
            if(Result.InteractState = trace_interaction_state.Free):
                set TargetMesh(0).Material_0 = TargetMesh(1)
            else:
                set TargetMesh(0).Material_0 = InteractingMaterial
               