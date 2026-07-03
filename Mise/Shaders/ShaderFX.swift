import SwiftUI

// SwiftUI-side wrappers for the Metal shaders in Mise.metal.
// Time-driven effects wrap their content in TimelineView(.animation) so the
// shader clock invalidates every frame; settled effects render statically.

extension View {

    /// Shimmering placeholder surface (colorEffect over the view's own fill).
    func plateShimmer() -> some View {
        modifier(PlateShimmer())
    }

    /// Film-grain develop for arriving imagery. `progress` 0→1; freezes at 1.
    func grainReveal(progress: Double) -> some View {
        modifier(GrainReveal(progress: progress))
    }

    /// Refractive glass chrome. Keep `strength` small (4–10).
    func liquidGlass(strength: Double = 6) -> some View {
        modifier(LiquidGlass(strength: strength))
    }

    /// Radial wobble tied to the zoom transition. 0 and 1 are rest states.
    func zoomRipple(progress: Double) -> some View {
        modifier(ZoomRipple(progress: progress))
    }

    /// Subtle rising warmth over hero imagery.
    func heatHaze() -> some View {
        modifier(HeatHaze())
    }
}

/// Shared clock value for shader uniforms — bounded so float precision stays fine.
private func shaderTime(_ date: Date) -> Double {
    date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
}

private struct PlateShimmer: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let t = shaderTime(context.date)
            content.visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.plateShimmer(.float2(proxy.size), .float(t))
                )
            }
        }
    }
}

private struct GrainReveal: ViewModifier {
    var progress: Double
    func body(content: Content) -> some View {
        if progress >= 1 {
            content
        } else {
            TimelineView(.animation) { context in
                let t = shaderTime(context.date)
                content.visualEffect { view, proxy in
                    view.layerEffect(
                        ShaderLibrary.grainReveal(
                            .float2(proxy.size), .float(progress), .float(t)
                        ),
                        maxSampleOffset: .zero
                    )
                }
            }
        }
    }
}

private struct LiquidGlass: ViewModifier {
    var strength: Double
    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let t = shaderTime(context.date)
            content.visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.liquidGlass(
                        .float2(proxy.size), .float(t), .float(strength)
                    ),
                    maxSampleOffset: CGSize(width: strength, height: strength)
                )
            }
        }
    }
}

private struct ZoomRipple: ViewModifier {
    var progress: Double
    func body(content: Content) -> some View {
        if progress <= 0.001 || progress >= 0.999 {
            content
        } else {
            content.visualEffect { view, proxy in
                view.distortionEffect(
                    ShaderLibrary.zoomRipple(.float2(proxy.size), .float(progress)),
                    maxSampleOffset: CGSize(width: 10, height: 10)
                )
            }
        }
    }
}

private struct HeatHaze: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.animation) { context in
            let t = shaderTime(context.date)
            content.visualEffect { view, proxy in
                view.layerEffect(
                    ShaderLibrary.heatHaze(.float2(proxy.size), .float(t)),
                    maxSampleOffset: CGSize(width: 3, height: 3)
                )
            }
        }
    }
}
