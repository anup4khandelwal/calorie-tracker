import SwiftUI

// SwiftUI wrappers for Mise.metal. Time-driven effects wrap content in a
// TimelineView clock at the lowest frame rate that still reads as alive;
// settled effects render statically and cost nothing.

extension View {

    /// The ambient page field (apply to a full-screen Rectangle).
    func ambientField() -> some View {
        modifier(AmbientField())
    }

    /// Placeholder while a photo generates — breathing studio light.
    func stillLife() -> some View {
        modifier(StillLife())
    }

    /// Photograph developing in. `progress` 0→1; freezes (free) at 1.
    func filmDevelop(progress: Double) -> some View {
        modifier(FilmDevelop(progress: progress))
    }

    /// Procedural smoked-glass chrome. `cornerRadius` must match the shape.
    func glassRim(cornerRadius: Double) -> some View {
        modifier(GlassRim(cornerRadius: cornerRadius))
    }

    /// Surface-tension wobble during the zoom. Rest states are free.
    func zoomRipple(progress: Double) -> some View {
        modifier(ZoomRipple(progress: progress))
    }
}

/// Bounded clock so float precision in the shader stays clean.
private func shaderTime(_ date: Date) -> Double {
    date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
}

private struct AmbientField: ViewModifier {
    func body(content: Content) -> some View {
        // The glow drifts over tens of seconds — 10fps is indistinguishable
        // from continuous here and keeps the GPU asleep most of the time.
        TimelineView(.animation(minimumInterval: 1.0 / 10.0)) { context in
            let t = shaderTime(context.date)
            content.visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.ambientField(.float2(proxy.size), .float(t))
                )
            }
        }
    }
}

private struct StillLife: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
            let t = shaderTime(context.date)
            content.visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.stillLife(.float2(proxy.size), .float(t))
                )
            }
        }
    }
}

private struct FilmDevelop: ViewModifier {
    var progress: Double
    func body(content: Content) -> some View {
        if progress >= 1 {
            content
        } else {
            TimelineView(.animation) { context in
                let t = shaderTime(context.date)
                content.visualEffect { view, proxy in
                    view.layerEffect(
                        ShaderLibrary.filmDevelop(
                            .float2(proxy.size), .float(progress), .float(t)
                        ),
                        maxSampleOffset: CGSize(width: 6, height: 6)
                    )
                }
            }
        }
    }
}

private struct GlassRim: ViewModifier {
    var cornerRadius: Double
    func body(content: Content) -> some View {
        // The rim light drifts slowly; the gleam crosses every ~22s.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = shaderTime(context.date)
            content.visualEffect { view, proxy in
                view.colorEffect(
                    ShaderLibrary.glassRim(
                        .float2(proxy.size), .float(t), .float(cornerRadius)
                    )
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
                    maxSampleOffset: CGSize(width: 4, height: 4)
                )
            }
        }
    }
}
