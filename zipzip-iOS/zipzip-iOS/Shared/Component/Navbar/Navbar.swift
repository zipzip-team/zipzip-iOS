//
//  Navbar.swift
//  zipzip-iOS
//
//  Created by 성환 on 7/6/26.
//

import SwiftUI

struct Navbar: View {
    @Binding var selection: NavbarTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(NavbarTab.allCases, id: \.self) { tab in
                item(for: tab)
            }
        }
        .padding(4)
        .background(.white00, in: .capsule)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 1)
    }

    private func item(for tab: NavbarTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                selection = tab
            }
        } label: {
            EmptyView()
        }
        .buttonStyle(NavbarItemButtonStyle(tab: tab, isSelected: isSelected, namespace: namespace))
    }
}

private struct NavbarItemButtonStyle: ButtonStyle {
    let tab: NavbarTab
    let isSelected: Bool
    let namespace: Namespace.ID

    func makeBody(configuration: Configuration) -> some View {
        let showsPressed = configuration.isPressed && !isSelected
        return VStack(spacing: 0) {
            Image(isSelected ? tab.selectedIcon : tab.unselectedIcon)
                .renderingMode(showsPressed ? .template : .original)
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(showsPressed ? .grey200 : .clear)
            Text(tab.title)
                .font(.b3_md)
                .foregroundStyle(showsPressed ? .grey200 : (isSelected ? .orange500 : .grey100))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 2)
        .background {
            if showsPressed {
                Capsule()
                    .fill(.grey50)
            } else if isSelected {
                Capsule()
                    .fill(.orange50)
                    .matchedGeometryEffect(id: "selectedTabBackground", in: namespace)
            }
        }
    }
}

#Preview {
    @Previewable @State var selection: NavbarTab = .main
    Navbar(selection: $selection)
        .padding()
}
