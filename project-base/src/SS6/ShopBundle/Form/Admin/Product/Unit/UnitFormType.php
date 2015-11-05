<?php

namespace SS6\ShopBundle\Form\Admin\Product\Unit;

use SS6\ShopBundle\Form\FormType;
use SS6\ShopBundle\Model\Product\Unit\UnitData;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolverInterface;
use Symfony\Component\Validator\Constraints;

class UnitFormType extends AbstractType {

	/**
	 * @return string
	 */
	public function getName() {
		return 'unit_form';
	}

	/**
	 * @param \Symfony\Component\Form\FormBuilderInterface $builder
	 * @param array $options
	 */
	public function buildForm(FormBuilderInterface $builder, array $options) {
		$builder
			->add('name', FormType::LOCALIZED, [
				'required' => true,
				'options' => [
					'constraints' => [
						new Constraints\NotBlank(['message' => 'Vyplňte prosím název jednotky ve všech jazycích']),
						new Constraints\Length(['max' => 10, 'maxMessage' => 'Název jednotky nesmí být delší než {{ limit }} znaků']),
					],
				],
			]);
	}

	/**
	 * @param \Symfony\Component\OptionsResolver\OptionsResolverInterface $resolver
	 */
	public function setDefaultOptions(OptionsResolverInterface $resolver) {
		$resolver->setDefaults([
			'data_class' => UnitData::class,
			'attr' => ['novalidate' => 'novalidate'],
		]);
	}

}