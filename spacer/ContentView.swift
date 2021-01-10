//
//  ContentView.swift
//  spacer
//
//  Created by Josee Wu on 03.01.21.
//

import SwiftUI
import Combine

struct ContentView: View {

    private let viewModel = SpacesListViewModel()
    var body: some View {
        Text("Hello, world!").onAppear {
            viewModel.fetchData()
        }
    }
}


class SpacesListViewModel: ObservableObject {
    private let service:Service = Service()
    private var cancelable:AnyCancellable?
    @Published var imagesViewModel = [ImagesViewModel]()
    func fetchData() {
        cancelable = service.fetch().sink { error in
            print(error)
        } receiveValue: { model in
            print(model)
        }
    }
    
}

struct ImagesViewModel {
    let title:String
    let url:String
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
