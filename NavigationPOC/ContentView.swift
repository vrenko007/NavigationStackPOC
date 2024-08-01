//
//  ContentView.swift
//  NavigationPOC
//
//  Created by Vrenko on 31. 7. 24.
//

import SwiftUI
import ComposableArchitecture

@Reducer(state: .equatable, action: .sendable)
enum Path {
  case flowA(FlowA)
  case flowB(FlowB)

  @ReducerBuilder<State, Action>
  static var body: some ReducerOf<Self>{
    Scope(state: \.flowA, action: \.flowA) {
      FlowA.body
    }
    Scope(state: \.flowB, action: \.flowB) {
      FlowB.body
    }
  }
}

@Reducer(state: .equatable, action: .sendable)
enum FlowA {
  case screen1(Screen)
  case screen2(Screen)
  case screen3(Screen)
  case screen4(Screen)
}

@Reducer(state: .equatable, action: .sendable)
enum FlowB {
  case flowBA(FlowBA)
  case flowBB(FlowBB)

  @ReducerBuilder<State, Action>
  static var body: some ReducerOf<Self> {
    Scope(state: \.flowBA, action: \.flowBA) {
      FlowBA.body
    }
    Scope(state: \.flowBB, action: \.flowBB) {
      FlowBB.body
    }
  }
}

@Reducer(state: .equatable, action: .sendable)
enum FlowBA {
  case screen1(Screen)
  case screen2(Screen)
}

@Reducer(state: .equatable, action: .sendable)
enum FlowBB {
  case screen1(Screen)
}

@Reducer
struct Screen {
  @ObservableState
  struct State: Equatable {
    @Shared var text: String
  }

  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case navigate(Shared<String>)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
  }
}

struct ShowView: View {
  let store: StoreOf<Screen>

  var body: some View {
    VStack {
      Text("Some View")
      Text(store.text)
      Button("Next") {
        store.send(.navigate(store.$text))
      }
    }
  }
}

struct EditView: View {
  @Bindable var store: StoreOf<Screen>


  var body: some View {
    VStack {
      Text("Edit Shared String")
      TextField("Shared Text", text: $store.text)
    }
  }
}

@Reducer(state: .equatable, action: .sendable)
enum Destination {
  case modal(Screen)
}

enum Tab: Hashable {
  case tab1
  case tab2
}

@Reducer
struct Root {
  @ObservableState
  struct State {
    var path = StackState<Path.State>()
    let child1 = Screen.State(text: Shared("Some String"))
    let child2 = Screen.State(text: Shared("Some String"))

    var selectedTab = Tab.tab1

    @Presents var destination: Destination.State?
  }

  enum Action {
    case path(StackActionOf<Path>)
    case child1(Screen.Action)
    case child2(Screen.Action)
    case destination(PresentationAction<Destination.Action>)
    case selectTab(Tab)
    case modal
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .modal:
        switch state.selectedTab {
        case .tab1:
          state.destination = .modal(Screen.State(text: state.child1.$text))
        case .tab2:
          state.destination = .modal(Screen.State(text: state.child2.$text))
        }
      case let .selectTab(tab):
        state.selectedTab = tab
      case let .child2(.navigate(text)):
        state.path.append(.flowB(.flowBA(.screen1(.init(text: text)))))
      case let .child1(.navigate(text)):
        state.path.append(.flowA(.screen1(.init(text: text))))
      case let .path(.element(id: _, action: .flowA(.screen1(.navigate(text))))):
        state.path.append(.flowA(.screen2(.init(text: text))))
      case let .path(.element(id: _, action: .flowA(.screen2(.navigate(text))))):
        state.path.append(.flowA(.screen3(.init(text: text))))
      case let .path(.element(id: _, action: .flowA(.screen3(.navigate(text))))):
        state.path.append(.flowA(.screen4(.init(text: text))))
      case let .path(.element(id: _, action: .flowA(.screen4(.navigate(text))))):
        state.path.append(.flowB(.flowBB(.screen1(.init(text: text)))))
      case let .path(.element(id: _, action: .flowB(.flowBA(.screen1(.navigate(text)))))):
        state.path.append(.flowB(.flowBA(.screen2(.init(text: text)))))
      case let .path(.element(id: _, action: .flowB(.flowBA(.screen2(.navigate(text)))))):
        state.path.append(.flowB(.flowBB(.screen1(.init(text: text)))))
      case .destination(.presented(.modal(.navigate))):
        state.destination = nil
      case .path, .child1, .child2, .destination:
        break
      }
      return .none
    }
    .forEach(\.path, action: \.path)
    .ifLet(\.$destination, action: \.destination)
  }

}

struct ContentView: View {
  let someString = Shared("Some String")

  @Bindable var store = Store(
    initialState: Root.State()) {
      Root()
    }

  var rootTitle: String {
    switch store.selectedTab {
    case .tab1:
      return "Root Tab1"
    case .tab2:
      return "Root Tab2"
    }
  }

  var body: some View {
    NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
      TabView(selection: $store.selectedTab.sending(\.selectTab)) {
        ShowView(store: store.scope(state: \.child1, action: \.child1))
          .tag(Tab.tab1)
          .tabItem {
            Text("Tab1")
          }
        ShowView(store: store.scope(state: \.child2, action: \.child2))
          .tag(Tab.tab2)
          .tabItem {
            Text("Tab2")
          }
      }
      .navigationTitle(rootTitle)
      .toolbar {
        ToolbarItem {
          Button {
            store.send(.modal)
          } label: {
            Image(systemName: "person.circle.fill")
          }
        }
      }
      .sheet(
        item: $store.scope(state: \.destination?.modal, action: \.destination.modal)) { modal in
          EditView(store: modal)
        }
      } destination: { path in
        switch path.case {
        case let .flowA(flowA):
          switch flowA.case {
          case let .screen1(child):
            ShowView(store: child)
              .navigationTitle("flowA screen1")
          case let .screen2(child):
            ShowView(store: child)
              .navigationTitle("flowA screen2")
          case let .screen3(child):
            ShowView(store: child)
              .navigationTitle("flowA screen3")
          case let .screen4(child):
            ShowView(store: child)
              .navigationTitle("flowA screen4")
          }
        case let .flowB(flowB):
          switch flowB.case {
          case let .flowBA(flowBA):
            switch flowBA.case {
            case let .screen1(child):
              ShowView(store: child)
                .navigationTitle("flowBA screen1")
            case let .screen2(child):
              ShowView(store: child)
                .navigationTitle("flowBA screen2")
            }
          case let .flowBB(flowBB):
            switch flowBB.case {
            case let .screen1(child):
              EditView(store: child)
                .navigationTitle("flowBB screen1")
            }
          }
        }
      }

  }
}

#Preview {
  ContentView()
}
