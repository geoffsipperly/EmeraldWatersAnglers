#!/usr/bin/env perl
# Brand-token sweep — rewrites raw SwiftUI Color/Font literals to Color/Font.brand*
# tokens defined in SkeenaSystem/Views/Shared/{Color,Font}+Brand.swift.
#
# Apply to a list of .swift files:  perl Scripts/brand_sweep.pl <files...>
#
# Patterns are intentionally restricted to unambiguous syntactic positions:
#   .foregroundColor(<color>)  — always a text/icon color
#   .background(Color.black)   — always a page background
#   Color.white.opacity(<n>)   — always a surface/stroke
#   Color.black.ignoresSafeArea() — always page background
#   .font(.<style>) and .font(.system(.<style>)) — always typography
# Anything that requires reading surrounding context (e.g. raw `.white` inside a
# RadialGradient mask) is left untouched and handled by hand.

use strict;
use warnings;

local $^I = '';   # in-place edit, no backup

while (<>) {
    # foregroundColor — text/icon colors
    s/\.foregroundColor\(\.white\)/.foregroundColor(.brandTextPrimary)/g;
    s/\.foregroundColor\(Color\.white\)/.foregroundColor(.brandTextPrimary)/g;
    s/\.foregroundColor\(\.gray\)/.foregroundColor(.brandTextSecondary)/g;
    s/\.foregroundColor\(Color\.gray\)/.foregroundColor(.brandTextSecondary)/g;
    s/\.foregroundColor\(\.blue\)/.foregroundColor(.brandAccent)/g;
    s/\.foregroundColor\(Color\.blue\)/.foregroundColor(.brandAccent)/g;
    s/\.foregroundColor\(\.red\)/.foregroundColor(.brandError)/g;
    s/\.foregroundColor\(Color\.red\)/.foregroundColor(.brandError)/g;
    s/\.foregroundColor\(\.green\)/.foregroundColor(.brandSuccess)/g;
    s/\.foregroundColor\(Color\.green\)/.foregroundColor(.brandSuccess)/g;
    s/\.foregroundColor\(\.orange\)/.foregroundColor(.brandWarning)/g;
    s/\.foregroundColor\(Color\.orange\)/.foregroundColor(.brandWarning)/g;

    # foregroundColor with .opacity(...) chained — text/icon colors at reduced opacity
    s/\.foregroundColor\(\.white\.opacity/.foregroundColor(.brandTextPrimary.opacity/g;
    s/\.foregroundColor\(Color\.white\.opacity/.foregroundColor(.brandTextPrimary.opacity/g;
    s/\.foregroundColor\(\.gray\.opacity/.foregroundColor(.brandTextSecondary.opacity/g;
    s/\.foregroundColor\(Color\.gray\.opacity/.foregroundColor(.brandTextSecondary.opacity/g;
    s/\.foregroundColor\(\.blue\.opacity/.foregroundColor(.brandAccent.opacity/g;
    s/\.foregroundColor\(\.red\.opacity/.foregroundColor(.brandError.opacity/g;
    s/\.foregroundColor\(\.green\.opacity/.foregroundColor(.brandSuccess.opacity/g;
    s/\.foregroundColor\(\.orange\.opacity/.foregroundColor(.brandWarning.opacity/g;

    # Surface / stroke literals (Color.white.opacity(<n>))
    s/Color\.white\.opacity\(0\.04\)/Color.brandSurfaceMuted/g;
    s/Color\.white\.opacity\(0\.05\)/Color.brandSurfaceMuted/g;
    s/Color\.white\.opacity\(0\.06\)/Color.brandStrokeSubtle/g;
    s/Color\.white\.opacity\(0\.07\)/Color.brandStrokeSubtle/g;
    s/Color\.white\.opacity\(0\.08\)/Color.brandSurface/g;
    s/Color\.white\.opacity\(0\.12\)/Color.brandStroke/g;
    s/Color\.white\.opacity\(0\.15\)/Color.brandStrokeStrong/g;

    # Nav-bar / panel surface
    s/Color\(UIColor\.systemGray6\)/Color.brandNavBar/g;

    # Page background literals
    s/Color\.black\.ignoresSafeArea\(\)/Color.brandBackground.ignoresSafeArea()/g;
    s/\.background\(Color\.black\)/.background(Color.brandBackground)/g;
    s/\.background\(\.black\)/.background(Color.brandBackground)/g;

    # Translucent dark scrim (over photos/maps) — stays dark across themes
    s/Color\.black\.opacity\(/Color.brandScrim.opacity(/g;

    # Action / status colors used as fills, tints, or backgrounds
    s/\.background\(Color\.blue\b/.background(Color.brandAccent/g;
    s/\.background\(Color\.red\b/.background(Color.brandError/g;
    s/\.background\(Color\.green\b/.background(Color.brandSuccess/g;
    s/\.background\(Color\.orange\b/.background(Color.brandWarning/g;
    s/\.fill\(Color\.blue\b/.fill(Color.brandAccent/g;
    s/\.fill\(Color\.red\b/.fill(Color.brandError/g;
    s/\.fill\(Color\.green\b/.fill(Color.brandSuccess/g;
    s/\.fill\(Color\.orange\b/.fill(Color.brandWarning/g;
    s/\.fill\(\.blue\)/.fill(Color.brandAccent)/g;
    s/\.fill\(\.red\)/.fill(Color.brandError)/g;
    s/\.fill\(\.green\)/.fill(Color.brandSuccess)/g;
    s/\.fill\(\.orange\)/.fill(Color.brandWarning)/g;
    s/\.tint\(\.blue\)/.tint(.brandAccent)/g;
    s/\.tint\(Color\.blue\)/.tint(.brandAccent)/g;
    s/\.foregroundStyle\(\.blue\)/.foregroundStyle(.brandAccent)/g;
    s/\.foregroundStyle\(\.red\)/.foregroundStyle(.brandError)/g;
    s/\.foregroundStyle\(\.green\)/.foregroundStyle(.brandSuccess)/g;
    s/\.foregroundStyle\(\.orange\)/.foregroundStyle(.brandWarning)/g;
    s/\.foregroundStyle\(\.white\)/.foregroundStyle(.brandTextPrimary)/g;
    s/\.foregroundStyle\(\.gray\)/.foregroundStyle(.brandTextSecondary)/g;

    # Base colors with arbitrary opacity — preserve numeric value, swap base.
    # Run AFTER the specific Color.white.opacity(<known>) replacements above so
    # the surface/stroke tokens win where applicable; remaining unmapped white
    # opacities fall through to brandTextPrimary which has the same value today.
    s/Color\.white\.opacity\(/Color.brandTextPrimary.opacity(/g;
    s/Color\.gray\.opacity\(/Color.brandTextSecondary.opacity(/g;
    s/Color\.blue\.opacity\(/Color.brandAccent.opacity(/g;
    s/Color\.red\.opacity\(/Color.brandError.opacity(/g;
    s/Color\.green\.opacity\(/Color.brandSuccess.opacity(/g;
    s/Color\.orange\.opacity\(/Color.brandWarning.opacity(/g;

    # SwiftUI list-row backgrounds (transparent rows on dark page)
    s/\.listRowBackground\(Color\.black\)/.listRowBackground(Color.brandBackground)/g;
    s/\.listRowBackground\(Color\.white\)/.listRowBackground(Color.brandSurfaceInverted)/g;

    # Inverted islands — white surfaces with black text (e.g. pill buttons)
    s/\.background\(Color\.white\)/.background(Color.brandSurfaceInverted)/g;
    s/\.foregroundColor\(\.black\)/.foregroundColor(.brandTextOnLight)/g;
    s/\.foregroundColor\(Color\.black\)/.foregroundColor(.brandTextOnLight)/g;

    # Bare Color.black (page-bg-equivalent) + black with edgesIgnoringSafeArea
    s/Color\.black\.edgesIgnoringSafeArea/Color.brandBackground.edgesIgnoringSafeArea/g;

    # Stroke / fill / tint with bare base colors
    s/\.stroke\(Color\.blue\b/.stroke(Color.brandAccent/g;
    s/\.stroke\(Color\.red\b/.stroke(Color.brandError/g;
    s/\.stroke\(Color\.green\b/.stroke(Color.brandSuccess/g;
    s/\.stroke\(Color\.orange\b/.stroke(Color.brandWarning/g;
    s/\.stroke\(Color\.gray\b/.stroke(Color.brandTextSecondary/g;
    s/\.strokeBorder\(Color\.white\.opacity/.strokeBorder(Color.brandTextPrimary.opacity/g;
    s/\.strokeBorder\(Color\.blue\b/.strokeBorder(Color.brandAccent/g;
    s/\.strokeBorder\(Color\.red\b/.strokeBorder(Color.brandError/g;

    # UIKit (UITextView etc.) backgrounds
    s/UIColor\.white\.withAlphaComponent\(0\.08\)/UIColor.brandSurface/g;

    # Typography — direct .font(.<style>...) form
    # Order matters: longer keys (title2/3, caption2) before shorter (title, caption)
    s/\.font\(\.largeTitle\b/.font(.brandLargeTitle/g;
    s/\.font\(\.title2\b/.font(.brandTitle2/g;
    s/\.font\(\.title3\b/.font(.brandTitle3/g;
    s/\.font\(\.title\b/.font(.brandTitle/g;
    s/\.font\(\.headline\b/.font(.brandHeadline/g;
    s/\.font\(\.subheadline\b/.font(.brandSubheadline/g;
    s/\.font\(\.body\b/.font(.brandBody/g;
    s/\.font\(\.footnote\b/.font(.brandFootnote/g;
    s/\.font\(\.caption2\b/.font(.brandCaption2/g;
    s/\.font\(\.caption\b/.font(.brandCaption/g;

    # Typography — .font(.system(.<style>)) form (same visual result, tokenize it)
    s/\.font\(\.system\(\.largeTitle\)\)/.font(.brandLargeTitle)/g;
    s/\.font\(\.system\(\.title2\)\)/.font(.brandTitle2)/g;
    s/\.font\(\.system\(\.title3\)\)/.font(.brandTitle3)/g;
    s/\.font\(\.system\(\.title\)\)/.font(.brandTitle)/g;
    s/\.font\(\.system\(\.headline\)\)/.font(.brandHeadline)/g;
    s/\.font\(\.system\(\.subheadline\)\)/.font(.brandSubheadline)/g;
    s/\.font\(\.system\(\.body\)\)/.font(.brandBody)/g;
    s/\.font\(\.system\(\.footnote\)\)/.font(.brandFootnote)/g;
    s/\.font\(\.system\(\.caption2\)\)/.font(.brandCaption2)/g;
    s/\.font\(\.system\(\.caption\)\)/.font(.brandCaption)/g;

    # Bare-color fallback — anything not caught above (ternaries, drawing
    # contexts, direct assignments, .strokeBorder(Color.white), etc.). Runs
    # LAST so the specific/contextual patterns above win where applicable.
    s/Color\.white\b/Color.brandTextPrimary/g;
    s/Color\.black\b/Color.brandBackground/g;
    s/Color\.gray\b/Color.brandTextSecondary/g;
    s/Color\.blue\b/Color.brandAccent/g;
    s/Color\.red\b/Color.brandError/g;
    s/Color\.green\b/Color.brandSuccess/g;
    s/Color\.orange\b/Color.brandWarning/g;

    s/UIColor\.white\b/UIColor.brandTextPrimary/g;
    s/UIColor\.black\b/UIColor.brandBackground/g;

    print;
}
