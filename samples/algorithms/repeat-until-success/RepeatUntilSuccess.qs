// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.
namespace Microsoft.Quantum.Samples.RepeatUntilSuccess {
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Preparation;
    open Microsoft.Quantum.Diagnostics;

    /// # Summary
    /// Example of a Repeat-until-success algorithm implementing a circuit 
    /// that achieves exp(i⋅ArcTan(2)⋅Z) by Paetznick & Svore. 
    /// Gate exp(i⋅ArcTan(2)⋅Z) is also know as V gate.
    /// # References
    /// - [ *Adam Paetznick, Krysta M. Svore*,
    ///     Quantum Information & Computation 14(15 & 16): 1277-1301 (2014)
    ///   ](https://arxiv.org/abs/1311.1074)
    /// For circuit diagram, see file RUS.png (to be added to README).
    ///
    /// The program executes a circuit on a "target" qubit using an "auxiliary" and 
    /// "resource" qubit. The circuit consists of two parts (red and blue in image).
    /// The goal is to measure Zero for both the auxiliary and resource qubit.
    /// If this succeeds, the program will have effectively applied an 
    /// Rz(arctan(2)) gate (also known as V_3 gate) on the target qubit.
    /// If this fails, the program reruns the circuit up to <limit> times.
    @EntryPoint()
    operation ApplyRzArcTan2(
        inputValue : Bool,
        inputBasis: Pauli,
        limit: Int
    ) : (Bool, Result, Int) {
        using ((auxiliary, resource, target) = (Qubit(), Qubit(), Qubit())) {
            // Initialize qubits to starting values (|+⟩, |+⟩, |0⟩/|1⟩)
            InitializeQubits(auxiliary, resource, target, inputBasis, inputValue);

            // Initialize results to One by default.
            mutable done = false;
            mutable success = false;
            mutable numIter = 0;

            repeat {
                // Assert valid starting states for all qubits
                AssertMeasurement([PauliX], [auxiliary], One, "Auxiliary qubit is not in |+⟩ state.");
                AssertMeasurement([PauliX], [resource], One, "Resource qubit is not in |+⟩ state.");
                AssertQubitIsInState(target, inputBasis, inputValue);

                // Run Part 1 of the program.
                let result1 = ApplyAndMeasurePart1(auxiliary, resource);
                // We'll only run Part 2 if Part 1 returns Zero.
                // Otherwise, we'll skip and rerun Part 1 again.
                if (result1 == Zero) { //0X
                    let result2 = ApplyAndMeasurePart2(resource, target);
                    if (result2 == Zero) { //00
                        set success = true;
                    } else { //01
                        Z(auxiliary); // Reset auxiliary from |-⟩ to |+⟩
                        Adjoint Z(target); // Correct effective Z rotation on target
                    }
                } else { //1X
                    // Set resource qubit back to |+⟩
                    Reset(resource);
                    X(resource);
                    PrepareQubit(PauliX, resource);
                }
                set done = (success or numIter >= limit);
                set numIter = numIter + 1;
            }
            until (done);

            let result = Measure([inputBasis], [target]);
            // From version 0.12 it is no longer necessary to release qubits in zero state.
            Reset(target);
            Reset(resource);
            Reset(auxiliary);

            return (success, result, numIter);
        }
    }

    /// Initialize axiliary and resource qubits in |+⟩, target in |0⟩ or |1⟩
    operation InitializeQubits(
        auxiliary: Qubit,
        resource: Qubit,
        target: Qubit,
        inputBasis: Pauli,
        inputValue: Bool
    ) : Unit {
        // Prepare auxiliary and resource qubits in |+⟩ state
        X(auxiliary);
        PrepareQubit(PauliX, auxiliary);
        X(resource);
        PrepareQubit(PauliX, resource);
        AssertMeasurement([PauliX], [auxiliary], One, "Auxiliary qubit is not in |+> state.");
        AssertMeasurement([PauliX], [resource], One, "Resource qubit is not in |+> state.");

        // Prepare target qubit in |0⟩ or |1⟩ state, depending on input value
        if (inputValue) {
            X(target);
        }
        PrepareQubit(inputBasis, target);
        AssertQubitIsInState(target, inputBasis, inputValue);
    }

    /// Part 1 of RUS circuit (red)
    operation ApplyAndMeasurePart1(
        auxiliary: Qubit,
        resource: Qubit
    ) : Result {
        within {
            Adjoint T(auxiliary);
        } apply {
            CNOT(resource, auxiliary);
        }

        return Measure([PauliX], [auxiliary]);
    }

    /// Part 2 of RUS circuit (blue)
    operation ApplyAndMeasurePart2(
        resource: Qubit,
        target: Qubit
    ) : Result {
        CNOT(target, resource);
        T(resource);
        T(target);
        
        return Measure([PauliX], [resource]);
    }

    /// Assert target qubit state is a given value in a given basis
    operation AssertQubitIsInState(
        target: Qubit,
        inputBasis: Pauli,
        inputValue: Bool
    ) : Unit {
        if (inputValue) {
            AssertMeasurement([inputBasis], [target], One, "Qubit is not in 1 state for given input basis.");
        } else {
            AssertMeasurement([inputBasis], [target], Zero, "Qubit is not in 0 state for given input basis.");
        }
    }
}
