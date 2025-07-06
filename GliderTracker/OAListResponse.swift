//
//  OAListResponse.swift
//  GliderTracker
//
//  Generic wrapper for OpenAIP list endpoints: { total, page, limit, items }
//
import Foundation

struct OAListResponse<Item: Decodable>: Decodable {
    let total: Int?
    let page: Int?
    let limit: Int?
    let items: [Item]
}