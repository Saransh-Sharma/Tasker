//
//  NewProjectViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 24/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

class NewProjectViewController: UIViewController {

    var peoplePickers: [PeoplePicker] = []
    static let verticalSpacing: CGFloat = 16
    static let margin: CGFloat = 16
    
    
    let addProjectContainer: UIStackView = createVerticalContainer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let yVal = 200
        
//        view.backgroundColor = .green
        
        addProjectContainer.frame =  CGRect(x: 0, y: 200, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        //CGRect(x: 0, y: yVal , width: Int(UIScreen.main.bounds.width), height: Int(UIScreen.main.bounds.height))
        
        view.addSubview(addProjectContainer)
        addProjectContainer.backgroundColor = .black
        addProjectContainer.addArrangedSubview(UIView())
        
        addPeoplePicker()
        addProjectContainer.addArrangedSubview(UIView())
        

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    
    func addPeoplePicker() {
        let peoplePicker = PeoplePicker()
        peoplePicker.label = "New Project Name:"
        peoplePicker.availablePersonas = samplePersonas
//        peoplePicker.pickedPersonas = variant.pickedPersonas
//        peoplePicker.showsSearchDirectoryButton = variant.showsSearchDirectoryButton
        peoplePicker.numberOfLines = 1 //variant.numberOfLines
        peoplePicker.allowsPickedPersonasToAppearAsSuggested = true//variant.allowsPickedPersonasToAppearAsSuggested
        peoplePicker.showsSearchDirectoryButton = false//variant.showsSearchDirectoryButton
        peoplePicker.delegate = self
        peoplePickers.append(peoplePicker)
        peoplePicker.becomeFirstResponder()
        addProjectContainer.addArrangedSubview(peoplePicker)
        
        
        
        
    }
    
    func showMessage(_ message: String, autoDismiss: Bool = true, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        present(alert, animated: true)

        if autoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.dismiss(animated: true)
            }
        } else {
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true, completion: completion)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            alert.addAction(okAction)
            alert.addAction(cancelAction)
        }

    }
    
    let samplePersonas: [PersonaData] = [
        PersonaData(name: "Kat Larrson", email: "kat.larrson@contoso.com", subtitle: "Designer", avatarImage: UIImage(named: "avatar_kat_larsson")),
        PersonaData(name: "Kristin Patterson", email: "kristin.patterson@contoso.com", subtitle: "Software Engineer"),
        PersonaData(name: "Ashley McCarthy", avatarImage: UIImage(named: "avatar_ashley_mccarthy")),
        PersonaData(name: "Carole Poland", email: "carole.poland@contoso.com", subtitle: "Software Engineer"),
        PersonaData(name: "Allan Munger", email: "allan.munger@contoso.com", subtitle: "Designer", avatarImage: UIImage(named: "avatar_allan_munger")),
        PersonaData(name: "Amanda Brady", subtitle: "Program Manager", avatarImage: UIImage(named: "avatar_amanda_brady")),
        PersonaData(name: "Kevin Sturgis", email: "kevin.sturgis@contoso.com", subtitle: "Software Engineeer"),
        PersonaData(name: "Lydia Bauer", email: "lydia.bauer@contoso.com", avatarImage: UIImage(named: "avatar_lydia_bauer")),
        PersonaData(name: "Robin Counts", subtitle: "Program Manager", avatarImage: UIImage(named: "avatar_robin_counts")),
        PersonaData(name: "Tim Deboer", email: "tim.deboer@contoso.com", subtitle: "Designer", avatarImage: UIImage(named: "avatar_tim_deboer")),
        PersonaData(email: "wanda.howard@contoso.com", subtitle: "Director"),
        PersonaData(name: "Daisy Phillips", email: "daisy.phillips@contoso.com", subtitle: "Software Engineer", avatarImage: UIImage(named: "avatar_daisy_phillips")),
        PersonaData(name: "Katri Ahokas", subtitle: "Program Manager", avatarImage: UIImage(named: "avatar_katri_ahokas")),
        PersonaData(name: "Colin Ballinger", email: "colin.ballinger@contoso.com", subtitle: "Software Engineer", avatarImage: UIImage(named: "avatar_colin_ballinger")),
        PersonaData(name: "Mona Kane", email: "mona.kane@contoso.com", subtitle: "Designer"),
        PersonaData(name: "Elvia Atkins", email: "elvia.atkins@contoso.com", subtitle: "Software Engineer", avatarImage: UIImage(named: "avatar_elvia_atkins")),
        PersonaData(name: "Johnie McConnell", subtitle: "Designer", avatarImage: UIImage(named: "avatar_johnie_mcconnell")),
        PersonaData(name: "Charlotte Waltsson", email: "charlotte.waltsson@contoso.com", subtitle: "Software Engineer"),
        PersonaData(name: "Mauricio August", email: "mauricio.august@contoso.com", subtitle: "Program Manager", avatarImage: UIImage(named: "avatar_mauricio_august")),
        PersonaData(name: "Robert Tolbert", email: "robert.tolbert@contoso.com", subtitle: "Software Engineer", avatarImage: UIImage(named: "avatar_robert_tolbert")),
        PersonaData(name: "Isaac Fielder", subtitle: "Designer", avatarImage: UIImage(named: "avatar_isaac_fielder")),
        PersonaData(name: "Elliot Woodward", subtitle: "Designer"),
        PersonaData(email: "carlos.slattery@contoso.com", subtitle: "Software Engineer"),
        PersonaData(name: "Henry Brill", subtitle: "Software Engineer", avatarImage: UIImage(named: "avatar_henry_brill")),
        PersonaData(name: "Cecil Folk", subtitle: "Program Manager", avatarImage: UIImage(named: "avatar_cecil_folk"))
    ]
    
    let searchDirectoryPersonas: [PersonaData] = [
        PersonaData(name: "Celeste Burton", email: "celeste.burton@contoso.com", subtitle: "Program Manager", avatarImage: UIImage(named: "avatar_celeste_burton")),
        PersonaData(name: "Erik Nason", email: "erik.nason@contoso.com", subtitle: "Designer"),
        PersonaData(name: "Miguel Garcia", email: "miguel.garcia@contoso.com", subtitle: "Software Engineer", avatarImage: UIImage(named: "avatar_miguel_garcia"))
    ]
    
    
    class func createVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        container.layoutMargins = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = verticalSpacing
        return container
    }
    
    

}

// MARK: - NewProjectViewController: PeoplePickerDelegate

extension NewProjectViewController: PeoplePickerDelegate {
    func peoplePicker(_ peoplePicker: PeoplePicker, personaFromText text: String) -> Persona {
        return samplePersonas.first { return $0.name.lowercased() == text.lowercased() } ?? PersonaData(name: text)
    }

    func peoplePicker(_ peoplePicker: PeoplePicker, personaIsValid persona: Persona) -> Bool {
        let availablePersonas = samplePersonas + searchDirectoryPersonas
//        return availablePersonas.contains { $0.name == persona.name }
//        if (availablePersonas.contains(persona.name)) {
        if (availablePersonas.contains { $0.name == persona.name }) {
            showMessage("\(persona.name) already exists !")
//            project = (persona.name)
        } else {
            showMessage("Added new project \(persona.name) ")
//            add & set project
            
            return true
        }
        return true
    }

    func peoplePicker(_ peoplePicker: PeoplePicker, didPickPersona persona: Persona) {
        if peoplePicker == peoplePickers.last {
            showMessage("\(persona.name) was picked")
        }
    }

    func peoplePicker(_ peoplePicker: PeoplePicker, didTapSelectedPersona persona: Persona) {
        peoplePicker.badge(for: persona)?.isSelected = false
        showMessage("\(persona.name) was tapped")
    }

    func peoplePicker(_ peoplePicker: PeoplePicker, searchDirectoryWithCompletion completion: @escaping ([Persona], Bool) -> Void) {
        // Delay added for 2 seconds to demo activity indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let text = peoplePicker.textFieldContent.lowercased()
            let personas = self.searchDirectoryPersonas.filter { $0.name.lowercased().contains(text) }
            completion(personas, true)
        }
    }
}


