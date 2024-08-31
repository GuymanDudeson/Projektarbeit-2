# Projektarbeit-2 Particle Simulation

## Content
This Repository is a Godot Project made as an assignment for the "Technische Hochschule Karslruhe".\
It contains a Godot scene and multiple scripts defining a simple particle simulation.\
The goal was to semi-accurately simulate water, the result is of varying success.\

Successes include:
- Particles are confined to a box
- Particles are aware of each other
- Particles now about the density of their position
- Particles apply pressure to other particles based on this density
- Particles generally strife to achive equal density
- Particles can be manipulated by the Mouse

Failures include:
- Particles have no viscosity
- Particles get very squished at the borders of the confining box
- Parameters are kinda finnicky => Simulation can become unstable
- Overall performance when going beyond 300 particles is lacking

## Inspiration
This project is heavily inspired by a creator called Sebastian Lague who made a similar simulation in Unity.
Most of the math and general optimization is based on his video: https://www.youtube.com/watch?v=rSKMYc1CQHE
My direct contribution is the realisation in Godot which brought a multitude of changes and problems that I fixed or ignored ^^.

## Future Goals
- Realizing the simulation as a Shader, which should be perfect for this kind of workload to maybe render tens or hundreds of thousands of particles
- General performance optimization for the density and pressure calculations
- Making particles viscose => Giving them surface tension 

