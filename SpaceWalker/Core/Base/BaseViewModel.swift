//
//  BaseViewModel.swift
//  SpaceWalker
//
//  Created by andev on 9/29/25.
//

import Foundation

protocol BaseViewModel {
    
    associatedtype Input
    associatedtype Output
    
    func transform(input: Input) -> Output
}
